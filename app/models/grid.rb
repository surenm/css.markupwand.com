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
      :orientation => self.orientation
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
      Log.info "Just one layer #{self.layers.first} is available. Adding to the grid"
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
  def extract_style_layers(grid, available_layers, parent_box = nil)
    return available_layers if (parent_box.nil? or available_layers.size == 1)
    
    # Get all the styles nodes at this level. These are the nodes that enclose every other nodes in the group
    style_layers = []
    if parent_box.kind_of? BoundingBox
      max_bounds = parent_box
    else
      Log.info "This is a grouping box"
      max_bounds = parent_box.bounds
      Log.info max_bounds
    end
    
    layers = {}
    available_layers.each { |key, layer| layers[key] = layer if max_bounds.encloses? layer.bounds }
    grid_style_layers = layers.values.select do |layer| 
      layer.bounds == max_bounds and layer.styleable_layer?
    end

    if grid_style_layers.size > 0
      Log.info "Style layers for Grid #{grid} are #{grid_style_layers}. Adding them to grid..." 
    end
    grid_style_layers.flatten!
    grid_style_layers.each { |style_layer| grid.style_layers.push style_layer.id.to_s }
    grid.style_layers.uniq!

    Log.info "Deleting #{style_layers} from grid" if style_layers.size > 0
    grid_style_layers.each { |style_layer| available_layers.delete style_layer.uid}

    return available_layers
  end
  
  # Get the row groups within this grid and try to process them one row at a time
  def get_subgrids
    Log.info "Getting subgrids (#{self.layers.length} layers in this grid)"

    # list of layers in this grid
    available_nodes = Hash[self.layers.collect { |item| [item.uid, item] }]
    available_nodes = available_nodes.select do |_, node|
      not node.empty?
    end
    
    layers_bounds = []
    available_nodes.values.each { |layer| layers_bounds.push layer.bounds }
    parent_box = BoundingBox.get_super_bounds layers_bounds
    
    # extract out style layers and parse with remaining        
    available_nodes = extract_style_layers self, available_nodes, parent_box
    
    # Some root grouping of nodes to recursive add as children
    root_grouping_box = BoundingBox.get_grouping_boxes available_nodes.values
    self.orientation = root_grouping_box.orientation
    self.save!

    Log.info "Trying Root grouping box: #{root_grouping_box}"    
    root_grouping_box.children.each do |row_grouping_box|
      if row_grouping_box.kind_of? BoundingBox
        available_nodes = process_grouping_box self, row_grouping_box, available_nodes
      else
        available_nodes = process_row_grouping_box row_grouping_box, available_nodes
      end
    end
    
    if available_nodes.length > 0
      Log.warn "Ignored nodes (#{available_nodes}) = #{available_nodes} in region #{self.bounds}" 
      Log.error self.bounds
      available_nodes.each do |_, node|
        Log.info "#{node.bounds}"
      end
    end
    
    self.save!
  end
  
  # Get an atomic group within a row grouping box and process them one group at a time
  def process_row_grouping_box(row_grouping_box, available_nodes)
    Log.info "Trying row grouping box: #{row_grouping_box}"
    
    row_grid       = Grid.new :design => self.design, :orientation => Constants::GRID_ORIENT_LEFT
    row_grid.depth = self.depth + 1
    row_grid.set [], self
            
    available_nodes = extract_style_layers row_grid, available_nodes, row_grouping_box
    
    row_grouping_box.children.each do |grouping_box|
      available_nodes = process_grouping_box row_grid, grouping_box, available_nodes
    end
    
    row_grid.save!
    
    # Bug here. 
    if row_grid.children.size == 1 and row_grid.style_layers.length == 0
      subgrid        = row_grid.children.first
      subgrid.parent = self
      subgrid.depth  = self.depth + 1
      row_grid.delete
    end
    
    return available_nodes
  end
  
  # Process a grouping box atomically
  def process_grouping_box(row_grid, grouping_box, available_nodes)
    Log.info "Trying grouping box: #{grouping_box}"
    
    nodes_in_region = BoundingBox.get_nodes_in_region grouping_box, available_nodes.values, zindex
    
    if nodes_in_region.empty?
      Log.info "Found padding region"

      # This is set so that the next box can pick it up as its offset box.
      self.design.offset_box_buffer = grouping_box.clone
    
    elsif nodes_in_region.size <= available_nodes.size
      grid = Grid.new :design => row_grid.design, :depth => row_grid.depth + 1
      
      # Reduce the set of nodes, remove style layers.
      available_nodes = extract_style_layers grid, available_nodes, grouping_box
      
      # Removes all intersecting layers also.
      if nodes_in_region.size == available_nodes.size
        nodes_in_region, positioned_layers = resolve_intersecting_nodes grid, nodes_in_region
        positioned_layers.each do |layer|
          available_nodes.delete layer.uid
        end
      end
      
      Log.info "Recursing inside, found #{nodes_in_region.size} nodes in region"
      
      grid.set nodes_in_region, row_grid
      nodes_in_region.each { |node| available_nodes.delete node.uid }
            
      if self.design.offset_box_buffer
        #Pickup spacing that the previous box allocated.
        grid.offset_box_buffer = BoundingBox.pickle self.design.offset_box_buffer

        #Reset the space
        self.design.offset_box_buffer = nil
      end

      # This grid needs to be called with sub_grids, push to grouping procesing queue
      @@grouping_queue.push grid
    end
    return available_nodes
  end
  
  ## Intersection methods.
  
  # Finds out intersecting nodes in lot of nodes
  def get_intersecting_nodes(nodes_in_region)
    intersecting_nodes = []
    
    intersect_found = false
    intersect_node_left = intersect_node_right = nil
    nodes_in_region.each do |node_left|
      nodes_in_region.each do |node_right|
        if node_left != node_right and node_left.intersect? node_right and !(node_left.encloses?(node_right) or \
          node_right.encloses?(node_left))
          intersecting_nodes.push node_right
          intersecting_nodes.push node_left
        end
      end
    end
    
    intersecting_nodes.uniq!
    
    return intersecting_nodes
  end

  # Find out whether it is inner intersect or outer intersect
  def find_intersect_type(intersecting_nodes)
    if intersecting_nodes.length == 2 
      intersect_area = intersecting_nodes.first.intersect_area(intersecting_nodes.second)
      intersect_percent_left = (intersect_area * 100.0) / Float(intersecting_nodes.first.bounds.area)
      intersect_percent_right = (intersect_area * 100.0) / Float(intersecting_nodes.second.bounds.area)
      if (intersect_percent_left > 90 or intersect_percent_right > 90)
        return :inner
      end
    end
    
    return :outer
  end
  
  # :left and :right are just conventions here. They don't necessarily 
  # depict their positions.
  def crop_inner_intersect(intersecting_nodes)
    smaller_node = intersecting_nodes[0]
    bigger_node  = intersecting_nodes[1]
    if intersecting_nodes[0].bounds.area > intersecting_nodes[1].bounds.area
      smaller_node = intersecting_nodes[1]
      bigger_node  = intersecting_nodes[0]
    end
    
    new_bound = BoundingBox.new(smaller_node.bounds.top, 
      smaller_node.bounds.left, smaller_node.bounds.bottom,
      smaller_node.bounds.right).inner_crop(bigger_node.bounds)
    
    smaller_node.bounds = new_bound
    
    [smaller_node, bigger_node]
  end
  
  def resolve_intersecting_nodes(grid, nodes_in_region)
    intersecting_nodes = get_intersecting_nodes nodes_in_region
    Log.info "Intersecting layers found - #{intersecting_nodes}"
    
    if intersecting_nodes.length > 1
      overlap_type = find_intersect_type intersecting_nodes
      
      
      if overlap_type == :inner
        # Less than 90%, crop them.

        cropped_nodes  = crop_inner_intersect(intersecting_nodes)
        modified_nodes = (nodes_in_region - intersecting_nodes + cropped_nodes)
        
        return  modified_nodes, []
      else
        # More than 90%, relatively position them
        
        # Sort Layers by their layer index.
        # Keep appending them
        intersecting_nodes.sort! { |node1, node2|  node2.zindex <=> node1.zindex }
        
        intersecting_nodes.each { |node| node.overlays = [] }

        # If some layerx is intersecting other layery, then layery needs to be just there,
        # layerx needs to be relatively positioned.
        # So, add layerx to layery's list of intersecting nodes.
        intersecting_nodes.each do |intersector|
          intersecting_nodes.each do |target|
            if intersector.intersect? target and
              intersector[:uid] != target[:uid] and
              not intersector.overlays.include? target[:uid]
              intersector.is_overlay = true
              target.overlays.push intersector[:uid]
            end
          end
        end
        
        # Once information is set that they are overlaid, remember them.
        positioned_layers = intersecting_nodes.select { |node| node.is_overlay == true }
        positioned_layers.sort! { |layer1, layer2| layer2.zindex <=> layer1.zindex }
        positioned_layers_children = []
        positioned_layers.each do |layer|
          positioned_grid = Grid.new :design => self.design
          nodes_in_grid = BoundingBox.get_nodes_in_region layer.bounds, nodes_in_region, layer.zindex
          positioned_layers_children = positioned_layers_children | nodes_in_grid
          nodes_in_region = nodes_in_region - nodes_in_grid
          positioned_grid.depth = self.depth + 1
          positioned_grid.set nodes_in_grid, self
          positioned_grid.is_positioned = true
          Log.info "Setting is_positioned = true for #{positioned_grid} (#{positioned_grid.id.to_s})"
          positioned_grid.save!
          @@grouping_queue.push positioned_grid
        end
        
        self.save!
        
        normal_layout_nodes = (nodes_in_region - positioned_layers - positioned_layers_children)
        
        return normal_layout_nodes, (positioned_layers | positioned_layers_children)
      end
    else
      Log.info "No intersecting node found, and no nodes reduced as well"
      return nodes_in_region, []
    end
  end
  
  # Finds out zindex of style layer
  def zindex
    zindex = nil
    if self.style_layers.length > 0
      self.style_layers.each do |layer_id|
        layer = Layer.find layer_id
        if not layer.unmaskable_layer?
          zindex = [zindex.to_i, layer.zindex].max
        end
      end
    end
    
    zindex
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
  
  ## Markup generation methods
  
  def positioned_grids_html(subgrid_args)
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
    attributes[:style]          = CssParser::to_style_string(self.style_selector.css_rules)

    if self.render_layer.nil?
      sub_grid_args = Hash.new
        
      child_nodes = self.children.select { |node| not node.is_positioned }
      child_nodes = child_nodes.sort { |a, b| a.id.to_s <=> b.id.to_s }
      child_nodes.each do |sub_grid|
        inner_html += sub_grid.to_html sub_grid_args
      end
      
      inner_html += positioned_grids_html(sub_grid_args)
      
      if child_nodes.length > 0
        html = content_tag tag, inner_html, attributes, false
      end
      
    else
      sub_grid_args = attributes
      sub_grid_args[tag] = self.tag
      render_layer_obj = Layer.find self.render_layer
      inner_html += render_layer_obj.to_html sub_grid_args, self.is_leaf?, self
      html = inner_html
    end
    
    return html
  end
end