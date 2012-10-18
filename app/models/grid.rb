require 'digest/md5'

class Grid  
  include ActionView::Helpers::TagHelper
  
  # An unique id to the grid
  attr_reader :id
  
  # Belongs to a specific photoshop design (Single Instance)
  attr_reader :design
  
  # self references for parent and children grids
  attr_accessor :parent #(Grid)
  attr_accessor :children #(Hash of Grid.id => Grid)

  # Layer types that belong to the grid
  attr_accessor :layers # (Hash of Layer.id => Layer)
  attr_accessor :style_layers  #(Hash of Layer.id => Layer)
  attr_accessor :render_layer #(Layer)

  # If this is a root grid of a design
  attr_accessor :root  #(Boolean)
  alias :root? :root

  # True if the grid node is going to be positioned
  attr_accessor :positioned  #(Boolean)
  alias :positioned? :positioned
    
  # Style and semantics related fields for a grid
  attr_accessor :style
  attr_accessor :orientation  #(Symbol)
  attr_accessor :tag  #(String)
  attr_accessor :override_tag  #(String)

  # Grouping related information for white spaces
  attr_accessor :offset_box  #(BoundingBox)
  attr_accessor :grouping_box  #(BoundingBox)
  
  ##########################################################
  # GRID INSTANTIATE
  ##########################################################
  
  def initialize(args)
    # If parent is nil, then this is a root node
    @root = args.fetch :root, false

    # Set parent for this grid
    @parent = args[:parent]

    # A grid always has to belong to a design    
    if @root
      @design = args[:design]
    else
      @design = parent.design
    end
    
    # If args contains an id, the grid is just being restored.
    # Else create a new id
    if args[:id].nil?
      @id = @design.get_next_grid_id
      @design.save_grid self
      @parent.add_child_grid self if not @root
    else
      # If args has id, it means its restored from sif data.
      # No need to reset parent relation as well as design relation
      @id = args[:id]
    end
    
    # Next all layers in this grid
    @layers = {}
    layers_array = args.fetch :layers, []
    layers_array.each {|layer| @layers[layer.uid] = layer}

    @style_layers = args.fetch :style_layers, {}
    @render_layer = args.fetch :render_layer, nil
    
    # populate children grids for this grid
    @children = args.fetch :children, {}

    # Grouping related boxes
    @grouping_box = args.fetch :grouping_box, nil
    @offset_box   = args.fetch :offset_box, nil
    @orientation  = args.fetch :orientation, Constants::GRID_ORIENT_NORMAL
    @positioned   = args.fetch :positioned, false
  
    # The html tag for this grid
    @tag = args.fetch :tag, :div
    
    # Grid styles
    style_args = args.fetch :style, {}

    style_args.update({:grid => self})
    @style = GridStyle.new(style_args)
    
    @@grouping_queue.push self if @root
  end
  
  def attribute_data
    parent_id       = @parent.id if not @root
    children_ids    = @children.keys
    layer_ids       = @layers.keys
    style_layer_ids = @style_layers.keys
    render_layer_id = @render_layer.uid if not @render_layer.nil?
    
    offset_box_data = @offset_box.attribute_data if not @offset_box.nil?
    grouping_box_data = @grouping_box.attribute_data if not @grouping_box.nil?
    
    attribute_data = {
      :id                => @id,
      :design            => @design.id,
      :parent            => parent_id,
      :layers            => layer_ids,
      :children          => children_ids,
      :style_layers      => style_layer_ids,
      :render_layer      => render_layer_id,
      :root              => @root,
      :positioned        => @positioned,
      :orientation       => @orientation,
      :tag               => @tag,
      :offset_box        => offset_box_data,
      :grouping_box      => grouping_box_data,
      :style             => @style.attribute_data
    }   

    return Utils::prune_null_items attribute_data   
  end
  
  ##########################################################
  # SPECIAL FUNCTIONS THAT NEED TO RESET ITSELF FROM SIF
  ##########################################################
  
  def add_child_grid(grid)
    @children[grid.id] = grid
  end
  
  def add_style_layers(style_layers)
    style_layers.each do |style_layer|
      @style_layers[style_layer.uid] = style_layer
    end
  end
  
  def set_render_layer(render_layer)
    @render_layer = render_layer
  end
  ##########################################################
  #  GRID OBJECT HELPERS
  ##########################################################
  def positioned_children
    self.children.values.select { |child_grid| child_grid.positioned? }
  end

  def positioned_siblings
    if not self.root
      self.parent.children.values.select { |sibling_grid| sibling_grid.positioned? }
    else
      []
    end
  end
  
  def has_positioned_children?
    return self.positioned_children.size > 0
  end

  def has_positioned_siblings?
    return self.positioned_siblings.size > 0
  end
  
  # Its a Leaf grid if it has no children and has one render layer
  def leaf?
    self.children.keys.size == 0 and not self.render_layer.nil?
  end

  def bounds
    if @layers.empty?
      bounds = nil
    else
      node_bounds = @layers.values.collect {|layer| layer.bounds}
      bounds = BoundingBox.get_super_bounds node_bounds
    end
    return bounds
  end
  
  def zindex
    zindex = 0
    
    all_layers_z_indices = []
    self.layers.each do |uid, layer|
      all_layers_z_indices.push layer.zindex
    end

    grid_zindex = all_layers_z_indices.min
    
    return grid_zindex
  end
  
  def tag
    if @tag.nil?
      if self.is_image_grid?
        @tag = 'img'
      else
        @tag = 'div'
      end
    end

    return @tag
  end
  
  def is_image_grid?
    if self.render_layer.nil?
      false
    else 
      (self.render_layer.tag_name == 'img')
    end
  end

  def is_text_grid?
    if self.render_layer.nil?
      false
    else
      (self.render_layer.type == Layer::LAYER_TEXT)
    end
  end
  
  ##########################################################
  # GRID GROUPING
  ##########################################################
  # Grouping queue is the order in which grids are processed
  @@grouping_queue = Queue.new
    
  def self.reset_grouping_queue
    @@grouping_queue.clear
  end
  
  # Grouping identifiers to detect infinite loop
  @@grouping_identifiers = Hash.new
  
  def unique_identifier
    layer_uids = self.layers.collect { |uid, layer| uid }
    raw_identifier = "#{self.design.id}-#{layer_uids.join '-'}"
    digest = Digest::MD5.hexdigest raw_identifier
    return digest
  end
  
  def get_grouping_count
    identifier = self.unique_identifier
    if not @@grouping_identifiers.has_key? identifier
      @@grouping_identifiers[identifier] = 0
    end
    return @@grouping_identifiers.fetch identifier
  end

  def increment_grouping_count
    @@grouping_identifiers[self.unique_identifier] = self.get_grouping_count + 1
  end

  def reset_grouping_count
    @@grouping_identifiers = Hash.new
  end
  
  # Start off the grouping for a design
  def self.group!
    while not @@grouping_queue.empty?
      grid = @@grouping_queue.pop
      
      if grid.get_grouping_count < Constants::GROUPING_MAX_RETRIES
        grid.increment_grouping_count
      else
        Log.fatal "Infinite loop detected..."
        grid.design.set_status Design::STATUS_FAILED
        raise "Infinite loop detected on layers - #{grid.layers.to_a}"
      end
      
      Log.info "Grouping #{grid.layers.values.to_a}..."
      grid.group!
    end
  end
  
  # Grouping a grid
  # If it just one layer, then add it as render layer
  # If it has more layers, than try to get the sub grids 
  def group!
    if self.layers.size > 1
      self.get_subgrids
    elsif self.layers.size == 1
      Log.info "Just one layer #{self.layers.values.first} is available..."
      self.set_render_layer self.layers.values.first
      self.layers.values.first.parent_grid = self
    end
  end
  
  ##########################################################
  # PROCESSING GROUPING BOXES
  ##########################################################
  # Helper method: Extract style layers out of a grid.
  # Usually any layer that matches the grouping box's bounds is a style layer
  def extract_style_layers(available_layers, parent_box = nil)
    return available_layers if (parent_box.nil? or available_layers.size == 1)
    
    # Get all the styles nodes at this level. These are the nodes that enclose every other nodes in the group
    if parent_box.kind_of? BoundingBox
      max_bounds = parent_box
    else
      max_bounds = parent_box.bounds
    end
    
    # If a text layer is a style layer, remove all the other layers, just return the 
    # text layer as the only layer and render the file.
    text_style_layers = layers.values.select do |layer|
      layer.bounds == max_bounds and layer.type == Layer::LAYER_TEXT
    end

    if text_style_layers.length > 0
      chosen_layer = text_style_layers.first
      return {"#{chosen_layer.uid}" => chosen_layer}
    end

    grid_style_layers = layers.values.select do |layer| 
      layer.bounds == max_bounds and layer.styleable_layer?
    end

    grid_style_layers.each do |layer|
      layer.style_layer = true
      layer.parent_grid = self
    end

    if grid_style_layers.size > 0
      Log.info "Extracting out the style layers #{grid_style_layers}..." 
      grid_style_layers.flatten!
      self.add_style_layers grid_style_layers

      Log.debug "Deleting #{grid_style_layers} from grid..."
      grid_style_layers.each { |style_layer| available_layers.delete style_layer.uid}
    end
    
    return available_layers
  end

  def extract_eclipsed_layers(available_nodes)
    eclipsed_layers = []

    available_nodes.each do |_, node_a|
      available_nodes.each do |_, node_b|
        if node_a != node_b
          if node_a.eclipses? node_b
            eclipsed_layers.push node_b
          end
        end
      end
    end

    eclipsed_layers.each do |layer|
      available_nodes.delete layer.uid
    end

    Log.info "Eclipsed layers = #{eclipsed_layers}"

    return available_nodes
  end
  
  # Get the row groups within this grid and try to process them one row at a time
  def get_subgrids
    Log.info "Getting subgrids (#{self.layers.length} layers in this grid)..."

    # list of layers in this grid
    all_nodes_copy = self.layers.dup

    # Filter out nodes that are inside the document
    available_nodes = {}

    all_nodes_copy.each do |id, layer|
      if not layer.bounds.nil?
        available_nodes[id] = layer
      else
        self.design.layers.delete id
        self.layers.delete id
      end
    end
    
    layers_bounds = available_nodes.values.collect { |layer| layer.bounds }
    parent_box = BoundingBox.get_super_bounds layers_bounds
    
    # extract out style layers and parse with remaining        
    Log.debug "Extracting style layers from root grid #{self}..."
    available_nodes = self.extract_style_layers available_nodes, parent_box
    available_nodes = self.extract_eclipsed_layers available_nodes

    # Some root grouping of nodes to recursive add as children
    root_grouping_box = BoundingBox.get_grouping_boxes available_nodes.values
    
    if not root_grouping_box.nil?
      self.orientation = root_grouping_box.orientation

      Log.debug "Trying Root grouping box: #{root_grouping_box}..."  
      root_grouping_box.children.each do |row_grouping_box|
        if row_grouping_box.kind_of? BoundingBox
          Log.debug "There is just one row/column. Processing it as a grouping_box..."
          available_nodes = process_grouping_box self, row_grouping_box, available_nodes
        else
          available_nodes = process_row_grouping_box row_grouping_box, available_nodes
        end
      end
    
      if available_nodes.length > 0
        Log.warn "Ignored nodes (#{available_nodes}) in region #{self.bounds}" 
      end
    end
  end
  
  # Get an atomic group within a row grouping box and process them one group at a time
  def process_row_grouping_box(row_grouping_box, available_nodes)
    Log.debug "Trying row grouping box #{row_grouping_box}..."
    
    nodes_in_row_region = BoundingBox.get_nodes_in_region row_grouping_box.bounds, available_nodes.values

    if nodes_in_row_region.empty?
      Log.info "No layers in #{row_grouping_box.bounds}. Marking this grouping box as margin..."
      self.design.row_offset_box = row_grouping_box.bounds
    else
      Log.info "Layers in this row group are #{nodes_in_row_region}. Creating a new row grid..."
      
      # if row grid offset is not nil, then set that as top margin for this row grid
      row_grid_offset_box = nil
      if not self.design.row_offset_box.nil?
        Log.info "Setting #{self.design.row_offset_box} as margin offset box for the above row grid..."
        row_grid_offset_box = self.design.row_offset_box
        self.design.reset_row_offset_box
      end

      row_grid = Grid.new ({  
        :parent => self,
        :layers => nodes_in_row_region,
        :orientation => Constants::GRID_ORIENT_LEFT,
        :grouping_box => row_grouping_box.bounds,
        :offset_box => row_grid_offset_box
      })
      
      Log.debug "Extracting style layers out of the row grid #{row_grid}"
      available_nodes = row_grid.extract_style_layers available_nodes, row_grouping_box
    
      row_grouping_box.children.each do |grouping_box|
        available_nodes = process_grouping_box row_grid, grouping_box, available_nodes
      end
      
      # reset any offset box buffer. Don't carry over to the new row
      Log.debug "Resetting previous row's offset box buffers..."
      self.design.reset_offset_box
    end
    
    return available_nodes
  end
  
  # Process a grouping box atomically
  def process_grouping_box(row_grid, grouping_box, available_nodes)
    Log.debug "Trying grouping box #{grouping_box}..."
    raw_grouping_box_layers = BoundingBox.get_nodes_in_region grouping_box, available_nodes.values, zindex
    
    if raw_grouping_box_layers.empty?
      Log.info "No layers in #{grouping_box}. Marking this grouping box as margin..."
      # TODO: Fix previous grid logic
      self.design.add_offset_box grouping_box.clone
    else
      Log.info "Layers in #{grouping_box} are #{raw_grouping_box_layers}. Creating a new grid..."

      Log.info "Checking for error intersections in layers #{raw_grouping_box_layers}"
      all_grouping_box_layers = Grid.fix_error_intersections raw_grouping_box_layers
      grouping_box_layers = Hash.new
      all_grouping_box_layers.each do |layer| 
        grouping_box_layers[layer.uid] = layer
        available_nodes.delete layer.uid
      end   
      
      grid_offset_box = nil
      if not self.design.offset_box.nil?
        Log.info "Setting #{self.design.offset_box} margin offset box for the above grid..."
        grid_offset_box = self.design.offset_box
        self.design.reset_offset_box
      end

      grid = Grid.new ({
        :parent => row_grid,
        :layers => grouping_box_layers.values,
        :grouping_box => grouping_box,
        :offset_box => grid_offset_box
      })
      
      # Reduce the set of nodes, remove style layers.
      Log.debug "Extract style layers for this grid #{grid}..."
      grouping_box_layers = grid.extract_style_layers grouping_box_layers, grouping_box

      # If where are still intersecting layers, make them positioned layers and remove them
      bounding_boxes    = grouping_box_layers.values.collect { |node| node.bounds }
      gutters_available = BoundingBox.grouping_boxes_possible? bounding_boxes
      positioning_done  = false
      if not gutters_available and grouping_box_layers.size > 1
        positioning_done = Grid.extract_positioned_layers grid, grouping_box, grouping_box_layers.values
      end
            
      # This grid is not positioned it might have subgrids, push to grouping procesing queue
      if not positioning_done
        @@grouping_queue.push grid
      end
    end
    return available_nodes
  end
  
  ## Intersection methods.
  # Finds out intersecting nodes in lot of nodes
  def self.get_intersecting_nodes(nodes_in_region)
    intersecting_node_pairs = []
    
    nodes_in_region.each do |node_left|
      nodes_in_region.each do |node_right|
        if node_left != node_right 
          if node_left.intersect? node_right and !(node_left.encloses? node_right or node_right.encloses? node_left)
            if node_left.zindex < node_right.zindex
              intersecting_node_pairs.push [node_left, node_right]
            else
              intersecting_node_pairs.push [node_right, node_left]
            end
          end
        end
      end
    end
    
    intersecting_node_pairs.uniq!
    Log.debug "Intersecting layers found - #{intersecting_node_pairs}"
    return intersecting_node_pairs
  end
  
  
  ##########################################################
  # FIX ERROR INTERSECTIONS
  ##########################################################
  def self.fix_error_intersections(layers_in_region)
    return layers_in_region if layers_in_region.size <= 1
    
    # TODO: edge case - a same layer could be intersecting with multiple layers. In this case that is not being handled.
    intersecting_pairs = Grid.get_intersecting_nodes layers_in_region
    
    intersecting_pairs.each do |intersecting_layers|
      layer_one = intersecting_layers.first
      layer_two = intersecting_layers.second
      
      intersect_bounds = layer_one.bounds.intersect_bounds layer_two.bounds
      
      next if layer_one.bounds.completely_encloses? intersect_bounds and layer_two.bounds.completely_encloses? intersect_bounds
      
      intersect_area = layer_one.intersect_area layer_two
      intersect_percent_left = (intersect_area * 100.0) / Float(layer_one.bounds.area)
      intersect_percent_right = (intersect_area * 100.0) / Float(layer_two.bounds.area)
      
      corrected_layers = nil
      if intersect_percent_left > 95 or intersect_percent_right > 95
        corrected_layers = Grid.crop_inner_intersect intersecting_layers
      elsif intersect_percent_left < 5 and intersect_percent_right < 5
        corrected_layers = Grid.crop_outer_intersect intersecting_layers
      end
      
      if not corrected_layers.nil?
        Log.info "Correcting an error intersection #{intersecting_layers} to #{corrected_layers}..."
        Log.info "intersecting_layers: #{Utils.debug_intersecting_layers intersecting_layers}"
        Log.info "corrected_layers: #{Utils.debug_intersecting_layers corrected_layers}"
        layers_in_region.delete intersecting_layers.first
        layers_in_region.delete intersecting_layers.second
        
        layers_in_region.push corrected_layers.first
        layers_in_region.push corrected_layers.second
      end
    end
    return layers_in_region
  end
  
  def self.crop_inner_intersect(intersecting_nodes)
    Log.info "Intersecting nodes"
    Log.info intersecting_nodes
    smaller_node = intersecting_nodes[0]
    bigger_node  = intersecting_nodes[1]
    if intersecting_nodes[0].bounds.area > intersecting_nodes[1].bounds.area
      smaller_node = intersecting_nodes[1]
      bigger_node  = intersecting_nodes[0]
    end

    new_bound = smaller_node.bounds.clone.inner_crop(bigger_node.bounds)
    smaller_node.bounds = new_bound
    
    [smaller_node, bigger_node]
  end
  
  def self.crop_outer_intersect(intersecting_nodes)
    smaller_node = intersecting_nodes[0]
    bigger_node  = intersecting_nodes[1]
    if intersecting_nodes[0].bounds.area > intersecting_nodes[1].bounds.area
      smaller_node = intersecting_nodes[1]
      bigger_node  = intersecting_nodes[0]
    end

    new_bound = smaller_node.bounds.clone.outer_crop(bigger_node.bounds)  
    smaller_node.bounds = new_bound
    
    [smaller_node, bigger_node]
  end
  
  def self.get_most_intersecting_layer(intersecting_layer_pairs)
    intersect_counts = Hash.new

    intersecting_layer_pairs.each do |pair|
      intersect_counts[pair.first] = 0 if intersect_counts[pair.first].nil?
      intersect_counts[pair.second] = 0 if intersect_counts[pair.second].nil?
      

      intersect_counts[pair.first] += 1
      intersect_counts[pair.second] += 1    
    end
    
    max_intersecting_layer = intersect_counts.sort {|a,b| a.second <=> b.second }.first
    
    return max_intersecting_layer.first
  end
  
  def self.extract_positioned_layers(grid, grouping_box, layers_in_region)
    intersecting_layer_pairs = Grid.get_intersecting_nodes layers_in_region
    
    if intersecting_layer_pairs.empty?
      Log.info "No intersecting layers found here..."
      return false 
    end
    
    layers_bounds = layers_in_region.collect { |layer| layer.bounds }
    offset_bounds = BoundingBox.get_super_bounds layers_bounds

    intersecting_layers = intersecting_layer_pairs.flatten.uniq
    intersecting_layers.sort! { |layer1, layer2| layer2.bounds.area <=> layer1.bounds.area }

    flow_layers_in_region = []
    largest_layer = intersecting_layers.delete_at 0

    Log.debug "Adding the layer #{largest_layer} as flow node..."
    flow_layers_in_region.push largest_layer

    # Sort by zindex so that topmost intersecting layer becomes parent for the node it contains
    intersecting_layers.sort! { |layer1, layer2| layer1.zindex <=> layer2.zindex }
    Log.debug  "Positioned Layers in region are #{intersecting_layers}"
    
    while not intersecting_layers.empty?
      layer = intersecting_layers.first

      layers_in_grid = BoundingBox.get_nodes_in_region layer.bounds, layers_in_region, layer.zindex
      
      intersecting_layers = intersecting_layers - layers_in_grid
      layers_in_region    = layers_in_region - layers_in_grid
      
      Log.info "Adding a new positioned grid with #{layers_in_grid}..."
      positioned_grid  = Grid.new ({
        :parent       => grid,
        :layers       => layers_in_grid,
        :positioned   => true,
        :grouping_box => layer.bounds
      })

      @@grouping_queue.push positioned_grid
    end
  
    flow_layers_in_region += layers_in_region
    Log.debug "Flow layers in region #{grouping_box} are #{flow_layers_in_region}."
    
    Log.info "Creating a new flow grid with #{flow_layers_in_region}..."
    flow_grid = Grid.new ({
      :parent => grid,
      :layers => flow_layers_in_region,
      :grouping_box => grouping_box,
      :offset_box => offset_bounds
    })
    
    @@grouping_queue.push flow_grid
    
    return (not intersecting_layer_pairs.empty?)
  end
  
  
  ##########################################################
  # Markup related functions
  ##########################################################
  def positioned_grids_html(subgrid_args = {})
    html = ''
    self.children.values.each do |grid|
      if grid.positioned?
        html += grid.to_html(subgrid_args)
      end
    end
    html
  end
  
  def to_html(args = {})
    Log.info "[HTML] #{self.to_s}, #{self.id.to_s}"
    html = ''
    
    # Is this required for grids?
    inner_html = args.fetch :inner_html, ''
  
    attributes = Hash.new
    attributes[:"data-grid-id"] = self.id.to_s

    if self.render_layer.nil?

      attributes[:class] = self.style.selector_names.join(" ") if not self.style.selector_names.empty?
 
      sub_grid_args = Hash.new
      positioned_html = positioned_grids_html sub_grid_args
      if not positioned_html.empty?
        inner_html += content_tag :div, '', :class => 'marginfix'
      end
      
      child_nodes = self.children.values.select { |node| not node.positioned }
      child_nodes = child_nodes.sort { |a, b| a.id.to_s <=> b.id.to_s }
      child_nodes.each do |sub_grid|
        inner_html += sub_grid.to_html sub_grid_args
      end

      inner_html += positioned_html
      
      if child_nodes.length > 0
        html = content_tag self.tag, inner_html, attributes, false
      end
      
    else
      sub_grid_args      = attributes
      sub_grid_args[tag] = self.tag

      sub_grid_args[:inner_html] = self.positioned_grids_html

      inner_html  += self.render_layer.to_html sub_grid_args
      

      if self.render_layer.tag_name == 'img'
        html = content_tag 'div', inner_html, {}, false
      else 
        html = inner_html
      end
    end
    
    return html
  end
  
  
  ##########################################################
  # Debug methods - inspect, to_s and print for a grid
  ##########################################################
  def inspect; to_s; end
  
  def to_s
    "Tag: #{self.tag}, Layers: #{self.layers.values}, Style layer: #{self.style_layers}, \
    Render layer: #{self.render_layer}"
  end

  def to_short_s
    if self.render_layer
      "Grid (render) #{self.render_layer.name}"
    else
      names = self.layers.map do |uid, layer|
        layer.name
      end
      "Grid (parent) #{names.to_s}"
    end
  end
  
 def print(indent_level=0)
    spaces = ""
    prefix = "|--"
    indent_level.times {|i| spaces+=" "}

    positioned_string = 'positioned' if positioned else ''
    Log.info "#{spaces}#{prefix} (Grid) #{self.bounds.to_s} [Style: #{self.style_layers.values.join(',')}], [Render: #{self.render_layer}] #{positioned_string}"
    self.children.each do |id, subgrid|
      subgrid.print(indent_level+1)
    end
    
    if children.length == 0
      self.layers.each do |uid, layer|
        layer.print(indent_level+1)
      end
    end  
  end
end
