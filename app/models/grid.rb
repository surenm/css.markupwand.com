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

  has_and_belongs_to_many :layers, :class_name => 'Layer'
  
  # fields relevant for a grid
  field :name, :type => String
  field :hash, :type => String
  field :orientation, :type => String, :default => Constants::GRID_ORIENT_NORMAL
  field :root, :type => Boolean, :default => false
  field :render_layer, :type => String, :default => nil
  field :style_layers, :type => Array, :default => []
  field :positioned_layers, :type => Array, :default => []
  
  field :css_hash, :type => Hash, :default => {}
  field :override_css_hash, :type => Hash, :default => {}
  
  field :tag, :type => String, :default => :div
  field :override_tag, :type => String, :default => nil
  
  field :width_class, :type => String, :default => ''
  field :override_width_class, :type => String, :default => nil
  field :is_positioned, :type => Boolean, :default => false

  field :offset_box, :type => String, :default => nil
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
    "Grid: Tag: #{self.tag}, Layers: #{self.layers.to_a}, Style layer: #{style_layer_objs}, \
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
  
  # Set data to a grid. More like a constructor, but mongoid models can't have the original constructors
  def set(layers, parent)
    # Pro-tip: http://ryanbigg.com/2010/04/has_and_belongs_to_many-double-insert/#comment-36741
    self.parent = parent
    layers.each { |layer| self.layers.push layer }
    self.save!
    
    @@grouping_queue.push self if self.root?
  end
    
  # Grid representational data
  def attribute_data
    {
      :id          => self.id,
      :name        => self.name,
      :css         => self.css_properties,
      :tag         => self.tag,
      :width_class => self.width_class,
      :orientation => self.orientation
    }
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
  
  # Helper method: Extract style layers out of a grid.
  # Usually any layer that matches the grouping box's bounds is a style layer
  def extract_style_layers(grid, available_layers, parent_box = nil)
    return available_layers if (parent_box.nil? or available_layers.size == 1)
    
    # Get all the styles nodes at this level. These are the nodes that enclose every other nodes in the group
    style_layers = []
    if parent_box.class.to_s == "BoundingBox"
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

    Log.info "Style layers for Grid #{grid} are #{grid_style_layers}. Adding them to grid..." if grid_style_layers.size > 0
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
    
    # Some root grouping of nodes to recursive add as children
    root_grouping_box = BoundingBox.get_grouping_boxes self.layers
    Log.info "Trying Root grouping box: #{root_grouping_box}"

    # list of layers in this grid
    available_nodes = Hash[self.layers.collect { |item| [item.uid, item] }]
    available_nodes = available_nodes.select do |_, node|
      not node.empty?
    end
    
    # extract out style layers and parse with remaining        
    available_nodes = extract_style_layers self, available_nodes, root_grouping_box

    root_grouping_box.children.each do |row_grouping_box|
      available_nodes = process_row_grouping_box row_grouping_box, available_nodes
    end
    
    Log.warn "Ignored nodes (#{available_nodes}) = #{available_nodes} in region #{self.bounds}" if available_nodes.length > 0
    if available_nodes.length > 0
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
      padding_offset_box = grouping_box.clone
    
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
      nodes_in_region.each {|node| available_nodes.delete node.uid}
        
      grid.offset_bounding_box = padding_offset_box if not padding_offset_box.nil?
      
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
        if node_left != node_right and node_left.intersect? node_right and !(node_left.encloses?(node_right) or node_right.encloses?(node_left))
          intersecting_nodes.push node_right
          intersecting_nodes.push node_left
        end
      end
    end
    
    intersecting_nodes.uniq!
    
    return intersecting_nodes
  end

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
        
        return crop_inner_intersect(intersecting_nodes), []
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
        positioned_layers.sort! { |layer1, layer2| layer1.zindex <=> layer2.zindex }
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
  
  ## Spacing and paddin related methods
   
  # Find out bounding box difference from it and its child.
  # Assumption is that it has only one child
  def padding_from_child
    child = children.first
    spacing = { :top => 0, :left => 0, :bottom => 0, :right => 0 }
    
    if bounds and child and child.bounds and children.length == 1
      spacing[:top]     = (child.bounds.top  - bounds.top)
      spacing[:bottom]  = (bounds.bottom - child.bounds.bottom)
      
      # Root elements are aligned using 960px, auto. Do not modify anything around
      # them.
      spacing[:left]  = (child.bounds.left - bounds.left) if not self.root
      spacing[:right] = (bounds.right - child.bounds.right ) if not self.root
    end
    
    spacing
  end
  
  # Spacing includes margin and padding.
  # Margin  = separate the block from things outside it
  # Padding = to move the contents away from the edges of the block.
  # 
  # There are two sources of spacing. 
  #  1. One is offset box (the empty sibling grid that offsets this box)
  #    a) This is always margin, never padding.
  #  2. Another is bounding box difference from its parent grid
  #    a) If it has a single child, calculate the bounding difference from
  #       child and add as padding.
  #    b) If it *is* a single child, do not accept bounding box difference,
  #       it would have got spacing from parent as padding.
  #    c) If it has more than one sibling, calculate relative margin. Absolute
  #       margin (term-invented-by-me) is distance top and left distance from 
  #       bounding box. Relative margin is the distance from it's sibling   
  #       (considering width and margins of its siblings.)
  #
  #    2(b) and 2(c) are exclusive
  def spacing_css
    #TODO. Margin and padding are not always from
    # left and top. It is from all sides.
    margin  = offset_box_spacing
    padding = padding_from_child
    css     = {}
    positions = [:top, :left, :bottom, :right]
    
    positions.each do |position|
      if margin.has_key? position
        css["margin-#{position}".to_sym] = "#{margin[position]}px" if margin[position] > 0
      end
      
      if padding.has_key? position
        css["padding-#{position}".to_sym] = "#{padding[position]}px" if padding[position] > 0
      end  
    end
    
    css
  end
  
  # For css
  # FIX Rename this function
  def offset_box_spacing
    offset_box_spacing = {:top => 0, :left => 0}
    
    if not self.offset_bounding_box.nil?
      if self.bounds.top - self.offset_bounding_box.top > 0
        offset_box_spacing[:top] = ( self.bounds.top - self.offset_bounding_box.top)
      end
      
      if self.bounds.left - self.offset_bounding_box.left > 0
        offset_box_spacing[:left] = (self.bounds.left - self.offset_bounding_box.left)
      end
    end
    
    offset_box_spacing
  end
  
  # Accessor for offset bounding box
  # De-serializes the offset box from mongo data.
  def offset_bounding_box
    BoundingBox.depickle self.offset_box
  end
  
  # Offset box is a box, that is an empty grid that appears before
  # this current grid. The previous sibling being a empty box, it adds itself
  # to a buffer. And the next item picks it up from buffer and takes it as its 
  # own offset bounding box.
  #
  # This function is for serializing bounding box and storing it.
  def offset_bounding_box= padding_bound_box;
    self.offset_box = BoundingBox.pickle padding_bound_box
  end
  
  def is_single_line_text
    if not self.render_layer.nil? and
      not (Layer.find self.render_layer).has_newline?
        return true
    else
      return false
    end
  end
  
  # Width subtracted by padding
  def unpadded_width
    if self.bounds.nil? or self.bounds.width.nil?
      nil 
    else
      padding = padding_from_child
      self.bounds.width - (padding[:left] + padding[:right])
    end
  end
  
  # Height subtracted by padding
  def unpadded_height
    if self.bounds.nil? or self.bounds.height.nil?
      nil 
    else
      padding = padding_from_child
      self.bounds.height - (padding[:top] + padding[:bottom])
    end
  end
  
  def set_width_class
    if not self.unpadded_width.nil?
      # Add a buffer of (960 + 10), because setting width of 960 in photoshop
      # is giving 962 in extendscript json. Debug more.
      if unpadded_width != 0 and unpadded_width <= 970
          self.width_class = StylesHash.get_bootstrap_width_class(unpadded_width)
      end
    end
  end
  
  # If the width has already not been set, set the width.
  # TODO Find out if there is any case when width is set.
  
  def width_css(css)
    if not css.has_key? :width and
      not is_single_line_text and
      unpadded_width != 0
        return {:width => unpadded_width.to_s + 'px'}
    end
    
    return {}
  end
  
  def css_properties(force=false)
    if self.css_hash.empty? or force
      css = {}
      self.style_layers.each do |layer_id|
        layer = Layer.find layer_id
        css.update layer.get_css({}, self.is_leaf?, self.root, self)
      end
      
      css.update width_css(css)
      css.delete :width if is_single_line_text

      # Set float.
      if not self.parent.nil? and self.parent.orientation == Constants::GRID_ORIENT_LEFT
        css[:float] = 'left'
      end
      
      # Positioning
      positioned_grid_count = (self.children.select { |grid| grid.is_positioned }).length
      css[:position] = 'relative' if positioned_grid_count > 0
      
      css.update CssParser::position_absolutely(self) if is_positioned
      

      # Gives out the values for spacing the box model.
      # Margin and padding
      css.update spacing_css

      # hack to make css non empty. Couldn't initialize css_hash as nil and check for nil condition
      css[:processed] = true
      
      self.css_hash.update css
      self.save!
    end
    
    # remove the processed css hack
    raw_properties = self.css_hash.clone
    raw_properties.delete "processed"
    return raw_properties
  end
  
  def tag
    if not self.override_tag.nil?
      self.override_tag
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
  
  def fix_children
    tag_handler = TagHandler.new self.id
    tag_handler.repair
  end
  
  def to_html(args = {})
    Log.info "[HTML] #{self.to_s}, #{self.id.to_s}"
    html = ''
    force = args.fetch :force, false
    layers_style_class = StylesHash.add_and_get_class CssParser::to_style_string self.css_properties(force)
    
    css_classes = []
    
    css_classes.push layers_style_class if not layers_style_class.nil?
    css_classes.push "clearfix" if self.orientation == Constants::GRID_ORIENT_LEFT
    
    css_class_string = css_classes.join " "
    
    # Is this required for grids?
    inner_html = args.fetch :inner_html, ''
    
    # debug attributes
    enable_data_attributes = args.fetch :enable_data_attributes, true
    
    attributes         = Hash.new
    attributes[:class] = css_class_string if not css_class_string.nil?
    attributes[:tag]   = self.tag

    attributes[:enable_data_attributes] = enable_data_attributes
    attributes[:"data-grid-id"]         = self.id.to_s if enable_data_attributes
        
    sub_grid_args = Hash.new
    sub_grid_args[:enable_data_attributes] = enable_data_attributes
    sub_grid_args[:force] = force
    if self.render_layer.nil?
      child_nodes = self.children.select { |node| not node.is_positioned }
      child_nodes = child_nodes.sort { |a, b| a.id.to_s <=> b.id.to_s }
      child_nodes.each do |sub_grid|
        inner_html += sub_grid.to_html sub_grid_args
      end
      
      if not self.children.empty? and self.orientation == "left"
        inner_html += content_tag :div, " ", { :style => "clear: both" }, false
      end
      
      inner_html += positioned_grids_html(sub_grid_args)
      
      if child_nodes.length > 0
        html = content_tag tag, inner_html, attributes, false
      end
      
    else
      sub_grid_args.update attributes
      render_layer_obj = Layer.find self.render_layer
      inner_html += render_layer_obj.to_html sub_grid_args, self.is_leaf?, self
      html = inner_html
    end
    
    return html
  end
end