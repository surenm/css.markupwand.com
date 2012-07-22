require 'digest/md5'

class Grid
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated  
  include ActionView::Helpers::TagHelper

  # Belongs to a specific photoshop design
  belongs_to :design

  # self references for children and parent grids
  has_many :children, :class_name => 'Grid', :inverse_of => :parent
  belongs_to :parent, :class_name => 'Grid', :inverse_of => :children
  embeds_one :style_selector, :class_name => 'GridStyleSelector'

  has_and_belongs_to_many :layers, :class_name => 'Layer'
  
  # fields relevant for a grid
  field :name, :type => String
  field :hash, :type => String
  field :orientation, :type => Symbol, :default => Constants::GRID_ORIENT_NORMAL
  field :root, :type => Boolean, :default => false
  field :render_layer, :type => String, :default => nil
  field :style_layers, :type => Array, :default => []
  field :positioned_layers, :type => Array, :default => []
  field :body_style_layers, :type => Array, :default => []
    
  field :tag, :type => String, :default => :div
  field :override_tag, :type => String, :default => nil
  
  field :is_positioned, :type => Boolean, :default => false

  field :offset_box_buffer, :type => String, :default => nil
  field :depth, :type => Integer, :default => -1
  
  field :grouping_box, :type => String, :default => nil
  
  # Grouping queue is the order in which grids are processed
  @@grouping_queue = Queue.new
  
  def self.reset_grouping_queue
    @@grouping_queue.clear
  end
  
  # Debug methods - inspect, to_s and print for a grid
  def inspect; to_s; end
  
  def to_s
    style_layer_objs = self.style_layers.collect do |style_layer_id|
      Layer.find(style_layer_id)
    end
    render_layer_obj = nil
    render_layer_obj = Layer.find self.render_layer if not self.render_layer.nil? 
    "Tag: #{self.tag}, Layers: #{self.layers.to_a}, Style layer: #{style_layer_objs}, \
    Render layer: #{render_layer_obj}"
  end

  def to_short_s
    if self.render_layer
      render_layer_obj = Layer.find self.render_layer
      "Grid (render) #{render_layer_obj.name}"
    else
      names = self.layers.map do |layer|
        layer.name
      end
      "Grid (parent) #{names.to_s}"
    end
  end
  
  def unique_identifier
    layer_uids = self.layers.collect { |layer| layer.uid }
    raw_identifier = "#{self.design.id}-#{layer_uids.join '-'}"
    digest = Digest::MD5.hexdigest raw_identifier
    return digest
  end
  
  def get_grouping_count
    count = Rails.cache.read self.unique_identifier
    if count.nil?
      design.add_grouping_identifier self.unique_identifier
      count = 0
    end
    return count
  end

  def increment_grouping_count
    count = self.get_grouping_count
    Rails.cache.write self.unique_identifier, (count + 1)
  end

  def reset_grouping_count
    Rails.cache.delete self.unique_identifier
  end
  
  def print(indent_level=0)
    spaces = ""
    prefix = "|--"
    indent_level.times {|i| spaces+=" "}

    style_layers = self.style_layers.map { |layer_id| Layer.find layer_id }
    Log.debug "#{spaces}#{prefix} (grid #{self.id.to_s}) #{self.bounds.to_s} (#{style_layers}, \
    positioned = #{is_positioned})"
    self.children.each do |subgrid|
      subgrid.print(indent_level+1)
    end
    
    if children.length == 0
      self.layers.each do |layer|
        layer.print(indent_level+1)
      end
    end  
  end
  
  # FIXME CSSTREE
  def get_label
    css_classes = [""] #+ self.get_css_classes
    css_classes_string = css_classes.join " ."
    "<div class='editable-grid'><span class='editable-tag'> #{self.tag} </span> <span class='editable-class'> #{css_classes_string} </span></div>"
  end
  
  # Set data to a grid. More like a constructor, but mongoid models can't have the original constructors
  def set(layers, parent)
    self.parent = parent
    layers.each { |layer| self.layers.push layer }
    self.style_selector = GridStyleSelector.new
    self.save!
    
    @@grouping_queue.push self if self.root?
  end
    
  # Grid representational data
  def attribute_data
    {
      :id          => self.id,
      :name        => self.name,
      :tag         => self.tag,
      :orientation => self.orientation,
      :zindex      => self.zindex
    }
  end
  
  def get_tree
    tree = {
      :id    => self.id,
      :tag   => self.tag,
      :label => self.get_label
    }
    
    tree[:children] = []

    if self.render_layer.nil?
      child_nodes = self.children.select { |node| not node.is_positioned }
      child_nodes = child_nodes.sort { |a, b| a.id.to_s <=> b.id.to_s }
      child_nodes.each do |child_node|
        tree[:children].push child_node.get_tree
      end
    else 
      render_layer_obj = Layer.find self.render_layer
      render_layer_attr_data = render_layer_obj.attribute_data
      render_layer_attr_data[:id] = self.id
      tree[:children].push render_layer_attr_data
    end
    return tree
  end
  
  def positioned_children
    self.children.select { |child_grid| child_grid.is_positioned }
  end
  
  def positioned_siblings
    if not self.root
      self.parent.children.select { |sibling_grid| sibling_grid.is_positioned }
    else
      []
    end
  end

  def siblings
    grid.parent.children.sort{|child1, child2| child1.grouping_box <=> child2.grouping_box} unless self.root
  end

  def last_processed_child
    if self.children.empty?
      return nil
    end
    self.children.sort {|a,b| a.id.to_s <=> b.id.to_s}.last
  end
  
  # Bounds for a grid.
  # TODO: cache this grids
  def bounds
    if self.layers.empty?
      bounds = nil
    else
      node_bounds = self.layers.collect {|layer| layer.bounds}
      bounds = BoundingBox.get_super_bounds node_bounds
    end
    return bounds
  end
  
  # Its a Leaf grid if it has no children and has one render layer
  def is_leaf?
    self.children.count == 0 and not self.render_layer.nil?
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
        raise "Infinite loop detected on layers - #{self.layers}"
      end
      
      Log.info "Grouping #{grid.layers.to_a}..."
      grid.group!
    end
  end
  
  # Grouping a grid
  # If it just one layer, then add it as render layer
  # If it has more layers, than try to get the sub grids 
  def group!
    if self.layers.size > 1
      get_subgrids
    elsif self.layers.size == 1
      Log.info "Just one layer #{self.layers.first} is available..."
      self.render_layer = self.layers.first.id.to_s
    end
    self.save!
  end
  
  ## Grid construction methods
  
  # Extracts out style layers that should be applied for body.
  # Different from normal style layers as it has to be applied to <body>
  # tag, and needs to be compared with the psd file's properties.

  def extract_body_style_layers
    Log.info "Extracting body style layers"
    body_style_layers = []
    design_bounds = BoundingBox.new(0, 0, design.height, design.width)
    self.layers.each do |layer|
      if layer.bounds.encloses? design_bounds
        Log.info "#{layer} is a body style layer"
        body_style_layers.push layer
      end
    end

    body_style_layers.each do |layer|
      self.layers.delete layer
    end

    self.body_style_layers = body_style_layers.map { |layer| layer.id }
  end
  
  # Helper method: Extract style layers out of a grid.
  # Usually any layer that matches the grouping box's bounds is a style layer
  def self.extract_style_layers(grid, available_layers, parent_box = nil)
    return available_layers if (parent_box.nil? or available_layers.size == 1)
    
    # Get all the styles nodes at this level. These are the nodes that enclose every other nodes in the group
    style_layers = []
    if parent_box.kind_of? BoundingBox
      max_bounds = parent_box
    else
      max_bounds = parent_box.bounds
    end
    
    layers = {}
    available_layers.each { |key, layer| layers[key] = layer if max_bounds.encloses? layer.bounds }
    grid_style_layers = layers.values.select do |layer| 
      layer.bounds == max_bounds and layer.styleable_layer?
    end

    grid_style_layers.each do |layer|
      layer.is_style_layer = true
      layer.save!
    end

    if grid_style_layers.size > 0
      Log.info "Extracting out the style layers #{grid_style_layers}..." 
      grid_style_layers.flatten!
      grid_style_layers.each { |style_layer| grid.style_layers.push style_layer.id.to_s }
      grid.style_layers.uniq!

      Log.debug "Deleting #{grid_style_layers} from grid..."
      grid_style_layers.each { |style_layer| available_layers.delete style_layer.uid}
    end
    return available_layers
  end
  
  # Get the row groups within this grid and try to process them one row at a time
  def get_subgrids
    Log.info "Getting subgrids (#{self.layers.length} layers in this grid)..."

    # list of layers in this grid
    available_nodes = Hash[self.layers.collect { |item| [item.uid, item] }]
    available_nodes = available_nodes.select do |_, node|
      not node.empty?
    end
    
    layers_bounds = []
    available_nodes.values.each { |layer| layers_bounds.push layer.bounds }
    parent_box = BoundingBox.get_super_bounds layers_bounds
    
    # extract out style layers and parse with remaining        
    Log.debug "Extracting style layers from root grid #{self}..."
    available_nodes = Grid.extract_style_layers self, available_nodes, parent_box
    
    # Some root grouping of nodes to recursive add as children
    root_grouping_box = BoundingBox.get_grouping_boxes available_nodes.values
    
    if not root_grouping_box.nil?
      self.orientation = root_grouping_box.orientation
      self.save!

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
    
    self.save!
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
      row_grid = Grid.new :design => self.design, 
                          :orientation => Constants::GRID_ORIENT_LEFT, 
                          :depth => self.depth + 1,
                          :grouping_box => BoundingBox.pickle(row_grouping_box.bounds)

      row_grid.set nodes_in_row_region, self
      
      Log.debug "Extracting style layers out of the row grid #{row_grid}"
      available_nodes = Grid.extract_style_layers row_grid, available_nodes, row_grouping_box
    
      row_grouping_box.children.each do |grouping_box|
        available_nodes = process_grouping_box row_grid, grouping_box, available_nodes
      end
      
      # reset previous row group's offset box buffer. Don't carry over to the new row
      Log.debug "Resetting previous row's offset box buffers..."
      self.design.reset_offset_box
      
      # if row grid offset is not nil, then set that as top margin for this row grid
      if not self.design.row_offset_box.nil?
        row_grid.offset_box_buffer = BoundingBox.pickle self.design.row_offset_box
        Log.info "Setting #{self.design.row_offset_box} as margin offset box for the above row grid..."
        self.design.reset_row_offset_box
      end
      row_grid.save!
    end
    
    return available_nodes
  end
  
  # Process a grouping box atomically
  def process_grouping_box(row_grid, grouping_box, available_nodes)
    Log.debug "Trying grouping box #{grouping_box}..."
    raw_grouping_box_layers = BoundingBox.get_nodes_in_region grouping_box, available_nodes.values, zindex
    
    if raw_grouping_box_layers.empty?
      Log.info "No layers in #{grouping_box}. Marking this grouping box as margin..."
      previous_grid = row_grid.last_processed_child
      previous_grid_layer = previous_grid.layers.first if !previous_grid.nil? and !previous_grid.layers.nil? and previous_grid.layers.size == 1
      if not previous_grid_layer.nil? and previous_grid_layer.kind == Layer::LAYER_TEXT and previous_grid_layer.text_type == "TextType.POINTTEXT"
        previous_grid.grouping_box = BoundingBox.pickle BoundingBox.get_super_bounds([previous_grid.bounds, grouping_box])
      else
        self.design.add_offset_box grouping_box.clone
      end
    else
      Log.info "Layers in #{grouping_box} are #{raw_grouping_box_layers}. Creating a new grid..."

      Log.info "Checking for error intersections in layers #{raw_grouping_box_layers}"
      all_grouping_box_layers = Grid.fix_error_intersections raw_grouping_box_layers
      grouping_box_layers = Hash.new
      all_grouping_box_layers.each do |layer| 
        grouping_box_layers[layer.uid] = layer
        available_nodes.delete layer.uid
      end    
            
      grid = Grid.new :design => row_grid.design, 
                      :depth  => row_grid.depth + 1, 
                      :grouping_box => BoundingBox.pickle(grouping_box)
      
      # Reduce the set of nodes, remove style layers.
      Log.debug "Extract style layers for this grid #{grid}..."
      grouping_box_layers = Grid.extract_style_layers grid, grouping_box_layers, grouping_box

      # If where are still intersecting layers, make them positioned layers and remove them
      bounding_boxes = grouping_box_layers.values.collect { |node| node.bounds }
      gutters_available = BoundingBox.grouping_boxes_possible? bounding_boxes
      is_positioning_done = false
      if not gutters_available and grouping_box_layers.size > 1
        is_positioning_done = Grid.extract_positioned_layers grid, grouping_box, grouping_box_layers.values
      end

      grid.set all_grouping_box_layers, row_grid
            
      if not self.design.offset_box.nil?
          grid.offset_box_buffer = BoundingBox.pickle self.design.offset_box

        Log.info "Setting #{self.design.offset_box} margin offset box for the above grid..."
        grid.save!

        #Reset the space
        self.design.reset_offset_box
      end

      # This grid needs to be called with sub_grids, push to grouping procesing queue
      if not is_positioning_done
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
  
  def self.fix_error_intersections(layers_in_region)
    # TODO: edge case - a same layer could be intersecting with multiple layers. In this case that is not being handled.
    intersecting_pairs = Grid.get_intersecting_nodes layers_in_region
    
    intersecting_pairs.each do |intersecting_layers|
      intersect_area = intersecting_layers.first.intersect_area(intersecting_layers.second)
      intersect_percent_left = (intersect_area * 100.0) / Float(intersecting_layers.first.bounds.area)
      intersect_percent_right = (intersect_area * 100.0) / Float(intersecting_layers.second.bounds.area)
      
      corrected_layers = nil
      if intersect_percent_left > 90 or intersect_percent_right > 90
        is_error_intersection = true
        corrected_layers = Grid.crop_inner_intersect intersecting_layers
      elsif intersect_percent_left < 10 and intersect_percent_right < 10
        is_error_intersection = true
        corrected_layers = Grid.crop_outer_intersect intersecting_layers
      end
      
      if not corrected_layers.nil?
        Log.info "Correcting an error intersection #{intersecting_layers} to #{corrected_layers}..."
        layers_in_region.delete intersecting_layers.first
        layers_in_region.delete intersecting_layers.second
        
        layers_in_region.push corrected_layers.first
        layers_in_region.push corrected_layers.second
      end
    end
    return layers_in_region
  end
  
  def self.crop_inner_intersect(intersecting_nodes)
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
      positioned_grid  = Grid.new :design => grid.design, :depth => grid.depth + 1, :is_positioned => true
      positioned_grid.set layers_in_grid, grid

      @@grouping_queue.push positioned_grid
    end
  
    flow_layers_in_region += layers_in_region
    Log.debug "Flow layers in region #{grouping_box} are #{flow_layers_in_region}."
    
    Log.info "Creating a new flow grid with #{flow_layers_in_region}..."
    flow_grid = Grid.new :design => grid.design, :depth => grid.depth + 1
    flow_grid.set flow_layers_in_region, grid
    flow_grid.offset_box_buffer = BoundingBox.pickle offset_bounds
    flow_grid.save!
    @@grouping_queue.push flow_grid
    
    return (not intersecting_layer_pairs.empty?)
  end
  
  # Finds out zindex of this grid
  def zindex
    zindex = 0
    layers_z_indices = self.layers.collect { |layer| layer.zindex }
    grid_zindex = layers_z_indices.min
    
    return grid_zindex
  end
  
  def tag
    if not self.override_tag.nil?
      self.override_tag.to_sym
    elsif self.is_image_grid?
      :img
    else
      :div
    end
  end
  
  def is_image_grid?
    if self.render_layer.nil?
      false
    else 
      render_layer_obj = Layer.find self.render_layer
      (render_layer_obj.tag_name(self.is_leaf?) == :img)
    end
  end

  def is_text_grid?
    if self.render_layer.nil?
      false
    else
      render_layer_obj = Layer.find self.render_layer
      (render_layer_obj.kind == Layer::LAYER_TEXT)
    end
  end
  
  ## Markup generation methods
  
  def positioned_grids_html(subgrid_args = {})
    html = ''
    self.children.each do |grid|
      if grid.is_positioned
        html += grid.to_html(subgrid_args)
      end
    end
    html
  end
  
  def fix_dom
    dom_parser = DomParser.new self.id
    dom_parser.reparse
  end
  
  def to_html(args = {})
    Log.info "[HTML] #{self.to_s}, #{self.id.to_s}"
    html = ''
    
    # Is this required for grids?
    inner_html = args.fetch :inner_html, ''
  
    attributes = Hash.new
    attributes[:"data-grid-id"] = self.id.to_s

    if self.render_layer.nil?

      attributes[:class] = self.style_selector.selector_names.join(" ") if not self.style_selector.selector_names.empty?
 
      sub_grid_args = Hash.new
      positioned_html = positioned_grids_html sub_grid_args
      if not positioned_html.empty?
        inner_html += content_tag :div, '', :class => 'marginfix'
      end
      
      child_nodes = self.children.select { |node| not node.is_positioned }
      child_nodes = child_nodes.sort { |a, b| a.id.to_s <=> b.id.to_s }
      child_nodes.each do |sub_grid|
        inner_html += sub_grid.to_html sub_grid_args
      end

      inner_html += positioned_html
      
      if child_nodes.length > 0
        html = content_tag tag, inner_html, attributes, false
      end
      
    else
      sub_grid_args      = attributes
      sub_grid_args[tag] = self.tag
      sub_grid_args[:inner_html] = self.positioned_grids_html

      render_layer_obj   = Layer.find self.render_layer
      inner_html        += render_layer_obj.to_html sub_grid_args, self.is_leaf?, self
      html               = inner_html
    end
    
    return html
  end
end