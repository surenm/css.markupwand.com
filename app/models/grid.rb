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
  field :fit_to_grid,  :type => Boolean, :default => true
  field :positioned_layers, :type => Array, :default => []
  
  field :css_hash, :type => Hash, :default => {}
  field :override_css_hash, :type => Hash, :default => {}
  
  field :tag, :type => String, :default => :div
  field :override_tag, :type => String, :default => nil
  
  field :width_class, :type => String, :default => ''
  field :override_width_class, :type => String, :default => nil
  

  field :offset_box, :type => Array, :default => []
  field :grid_depth, :type => Integer, :default => -1
  

  @@pageglobals    = PageGlobals.instance
  @@grouping_queue = Queue.new
  
  
  def set(layers, parent)
    self.parent = parent
    
    # Spent close to fucking one day trying to debug this.
    # Just trying to access this self.layer once, helps avoiding redundant  
    # inserts into the same group.
    #
    # Just remove the Log.info line below, and code will start breaking.
    # Magic! 
    # Pro-tip: http://ryanbigg.com/2010/04/has_and_belongs_to_many-double-insert/#comment-36741
    
    #Log.info self.layers.to_a # DO NOT REMOVE THIS LINE - Alagu
    layers.each { |layer| self.layers.push layer }
    self.layers.sort!
    self.save!
    
    @@grouping_queue.push self if self.root?
  end
  
  def to_s
    "Grid #{self.layers.to_a}, Style Layers: #{@layers.to_a}"
  end
  
  def print(indent_level=0)
    spaces = ""
    prefix = "|--"
    indent_level.times {|i| spaces+=" "}

    Log.debug "#{spaces}#{prefix} (grid) #{self.bounds.to_s}"
    self.children.each do |subgrid|
      subgrid.print(indent_level+1)
    end
    
    if children.length == 0
      self.layers.each do |layer|
        layer.print(indent_level+1)
      end
    end  
  end
    
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
  
  def bounds
    if layers.empty?
      bounds = nil
    else
      node_bounds = self.layers.collect {|layer| layer.bounds}
      bounds = BoundingBox.get_super_bounds node_bounds
    end
    return bounds
  end 
  
  def is_leaf?
    self.children.count == 0 and not self.render_layer.nil?
  end
  
  def depth
    if self.grid_depth == -1
      depth = 0
      parent = self.parent
      while not parent.nil?
        parent = parent.parent
        depth = depth + 1
      end
      self.grid_depth = depth
      self.save!
    end
    
    self.grid_depth
  end

  
  def self.reset_grouping_queue
    @@grouping_queue.clear
  end

  def self.group!
    while not @@grouping_queue.empty?
      grid = @@grouping_queue.pop
      grid.group!
    end
  end
  
  def group!
    if self.layers.size > 1
      get_subgrids
    elsif self.layers.size == 1
      Log.debug "Just one layer #{self.layers.first} is available. Adding to the grid"
      self.render_layer = self.layers.first.id.to_s
    end
    self.save!
  end
  

  # Usually any layer that matches the grouping box's bounds is a style layer
  def extract_style_layers(grid, available_layers, parent_box = nil)
    return available_layers if parent_box.nil?
    
    # Get all the styles nodes at this level. These are the nodes that enclose every other nodes in the group
    style_layers = []
    if parent_box.class.to_s == "BoundingBox"
      max_bounds = parent_box
    else
      max_bounds = parent_box.bounds
    end
    
    layers = {}
    available_layers.each { |key, layer| layers[key] = layer if max_bounds.encloses? layer.bounds }
    grid_style_layers = layers.values.select do |layer| 
      layer.bounds == max_bounds and layer.styleable_layer?
    end

    Log.info "Style layers for Grid #{grid} are #{grid_style_layers}. Adding them to grid..." if style_layers.size > 0
    grid_style_layers.flatten!
    grid_style_layers.each { |style_layer| grid.style_layers.push style_layer.id.to_s }

    Log.debug "Deleting #{style_layers} from grid" if style_layers.size > 0
    grid_style_layers.each { |style_layer| available_layers.delete style_layer.uid}

    return available_layers
  end
  
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

  def get_subgrids
    Log.debug "Getting subgrids (#{self.layers.length} layers in this grid)"
    
    # Some root grouping of nodes to recursive add as children
    root_grouping_box = BoundingBox.get_grouping_boxes self.layers
    Log.debug "Trying Root grouping box: #{root_grouping_box}"

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
    
    self.save!
  end
  
  def process_row_grouping_box(row_grouping_box, available_nodes)
    Log.debug "Trying row grouping box: #{row_grouping_box}"
    
    row_grid       = Grid.new :design => self.design, :orientation => Constants::GRID_ORIENT_LEFT
    row_grid.grid_depth = self.grid_depth + 1
    row_grid.set [], self
            
    available_nodes = extract_style_layers row_grid, available_nodes, row_grouping_box
    
    row_grouping_box.children.each do |grouping_box|
      available_nodes = process_grouping_box row_grid, grouping_box, available_nodes
    end
    
    row_grid.save!
    
    if row_grid.children.size == 1
      subgrid        = row_grid.children.first
      subgrid.parent = self
      subgrid.grid_depth  = self.grid_depth + 1
      row_grid.delete
    end
    
    return available_nodes
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
    
    if intersecting_nodes.length > 0
      overlap_type = find_intersect_type intersecting_nodes
      
      
      if overlap_type == :inner
        # Less than 90%, crop them.
        
        return crop_inner_intersect(intersecting_nodes)
      else
        # More than 90%, relatively position them
        
        # Sort Layers by their layer index.
        # Keep appending them
        intersecting_nodes.sort! { |node1, node2|  node2.layer_object[:itemIndex][:value] <=>  node1.layer_object[:itemIndex][:value] }
        
        intersecting_nodes.each { |node| node.overlays = [] }

        # If some layerx is intersecting other layery, then layery needs to be just there,
        # layerx needs to be relatively positioned.
        # So, add layerx to layery's list of intersecting nodes.
        intersecting_nodes.each do |intersector|
          intersecting_nodes.each do |target|
            if intersector.intersect? target and
              intersector[:uid] != target[:uid] and
              not intersector.overlays.include? target[:uid]
              intersector.am_i_overlay = true
              target.overlays.push intersector[:uid]
            end
          end
        end
        
        # Once information is set that they are overlaid, remember them.
        positioned_layers = intersecting_nodes.select { |node| node.am_i_overlay == true }
        positioned_layers.each { |node| node.save! }
        
        grid.positioned_layers = positioned_layers.map { |node| node.id.to_s }
        normal_layout_nodes = intersecting_nodes.select { |node| node.am_i_overlay != true }
        
        return normal_layout_nodes
      end
    else
      Log.error "No intersecting node found, and no nodes reduced as well"
    end
  end
  
  def process_grouping_box(row_grid, grouping_box, available_nodes)
    Log.debug "Trying grouping box: #{grouping_box}"

    nodes_in_region = BoundingBox.get_objects_in_region grouping_box, available_nodes.values, :bounds
    
    if nodes_in_region.empty?
      Log.info "Found padding region"
      @@pageglobals.add_offset_box grouping_box
      
    elsif nodes_in_region.size <= available_nodes.size
      grid = Grid.new :design => row_grid.design, :grid_depth => row_grid.grid_depth + 1
      
      # Reduce the set of nodes, remove style layers.
      extract_style_layers grid, available_nodes, grouping_box
      
      # Removes all intersecting layers also.
      if nodes_in_region.size == available_nodes.size
        nodes_in_region = resolve_intersecting_nodes grid, nodes_in_region
        grid.positioned_layers.each do |layer_id|
          layer = Layer.find layer_id
          available_nodes.delete layer.uid
        end
      end
      
      Log.info "Recursing inside, found #{nodes_in_region.size} nodes in region"
      
      grid.set nodes_in_region, row_grid
      nodes_in_region.each {|node| available_nodes.delete node.uid}
                
      if not @@pageglobals.offset_box_buffer.nil?
        grid.offset_bounding_box = @@pageglobals.offset_box_buffer.clone
        @@pageglobals.reset_offset_buffer
      end
      
      # This grid needs to be called with sub_grids, push to grouping procesing queue
      @@grouping_queue.push grid
    end
    return available_nodes
  end
  
  
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
  #    2(b) and 2(c) are exclusive.

  
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
  def offset_bounding_box; BoundingBox.from_mongo(offset_box) end
  
  # Offset box is a box, that is an empty grid that appears before
  # this current grid. The previous sibling being a empty box, it adds itself
  # to a buffer. And the next item picks it up from buffer and takes it as its 
  # own offset bounding box.
  #
  # This function is for serializing bounding box and storing it.
  def offset_bounding_box= padding_bound_box;
    self.offset_box = padding_bound_box.serialize
  end
  
  def is_single_line_text
    if not self.render_layer.nil?
      render_layer_obj = Layer.find self.render_layer
      if render_layer_obj.kind == Layer::LAYER_TEXT and not render_layer_obj.has_newline?
        return true
      end
    end
    
    return false
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
          self.width_class = PhotoshopItem::StylesHash.get_bootstrap_width_class(unpadded_width)
      end
    end
  end
  
  # If the width has already not been set, set the width.
  # TODO Find out if there is any case when width is set.
  
  def width_css(css)
    if self.fit_to_grid and self.depth < 5 and not is_image_grid?
      set_width_class
    elsif not css.has_key? :width
      if not is_single_line_text and unpadded_width != 0
        return {:width => unpadded_width.to_s + 'px'}
      end
    end
    
    return {}
  end
  
  def css_properties
    if self.css_hash.empty?
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
      
      if self.positioned_layers.length > 0
        css[:position] = 'relative'
      end

      # Gives out the values for spacing the box model.
      # Margin and padding
      css.update spacing_css

      # hack to make css non empty. Couldn't initialize css_hash as nil and check for nil condition
      css[:processed] = true
      
      self.css_hash.update css
      self.save!
    end
    
    # remove the processed css hack
    raw_properties = self.css_hash
    raw_properties.delete "processed"
    return raw_properties
  end
  
  def tag
    if not self.override_tag.nil?
      self.override_tag
    elsif self.root
      :body
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
  
  def positioned_layers_html(subgrid_args)
    html = ''
    self.positioned_layers.each do |layer_id|
      layer = Layer.find layer_id
      html += layer.to_html(subgrid_args, self.is_leaf?)
    end
    
    html
  end
  
  def to_html(args = {})
    html = ''
    layers_style_class = PhotoshopItem::StylesHash.add_and_get_class CssParser::to_style_string self.css_properties
    
    css_classes = []
    
    css_classes.push layers_style_class if not layers_style_class.nil?
    css_classes.push "row" if self.orientation == Constants::GRID_ORIENT_LEFT
    css_classes.push self.width_class if (not self.width_class.nil? and not is_image_grid?)
    
    css_class_string = css_classes.join " "
    
    # Is this required for grids?
    inner_html = args.fetch :inner_html, ''

    attributes                  = Hash.new
    attributes[:class]          = css_class_string if not css_class_string.nil?
    attributes[:"data-grid-id"] = self.id.to_s
    
    sub_grid_args = Hash.new
    if self.render_layer.nil?

      child_nodes = self.children.sort { |a, b| a.id.to_s <=> b.id.to_s }
      child_nodes.each do |sub_grid|
        inner_html += sub_grid.to_html sub_grid_args
      end
      
      inner_html += positioned_layers_html(sub_grid_args)

      if not self.children.empty? and self.orientation == "left"
        inner_html += content_tag :div, " ", { :style => "clear: both" }, false
      end

      if child_nodes.length > 0
        html = content_tag tag, inner_html, attributes, false
      end
      
    else
      sub_grid_args.update attributes
      sub_grid_args[:tag] = tag
      render_layer_obj = Layer.find self.render_layer
      inner_html += render_layer_obj.to_html sub_grid_args, self.is_leaf?, self

      html = inner_html
    end
    
    return html
  end
end