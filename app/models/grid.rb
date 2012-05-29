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

  has_many :layers, :class_name => 'Layer'
  
  # fields relevant for a grid
  field :name, :type => String
  field :hash, :type => String
  field :orientation, :type => String, :default => Constants::GRID_ORIENT_NORMAL
  field :root, :type => Boolean, :default => false
  field :render_layer, :type => String, :default => nil
  field :style_layers, :type => Array, :default => []
  field :offset_box, :type => Array, :default => []
  field :fit_to_grid,  :type => Boolean, :default => true
  
  field :css_hash, :type => Hash, :default => {}
  field :override_css_hash, :type => Hash, :default => {}
  
  field :tag, :type => String, :default => :div
  field :override_tag, :type => String, :default => nil
  
  field :width_class, :type => String, :default => ''
  field :override_width_class, :type => String, :default => nil

  @@pageglobals = PageGlobals.instance
  
  attr_accessor :relative_margin
  
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
  
  def is_leaf?
    self.children.count == 0 and not self.render_layer.nil?
  end
  
  def self.reset_grouping_queue
    @@pageglobals.grouping_queue.clear
  end

  def self.group!
    while not @@pageglobals.grouping_queue.empty?
      grid = @@pageglobals.grouping_queue.pop
      grid.group!
    end
  end

  def self.get_vertical_gutters(bounding_boxes)
    vertical_lines  = bounding_boxes.collect{|bb| bb.left}
    vertical_lines += bounding_boxes.collect{|bb| bb.right}
    vertical_lines.uniq!

    vertical_gutters = []
    vertical_lines.each do |vertical_line|
      is_gutter = true
      bounding_boxes.each do |bb|
        if bb.left < vertical_line and vertical_line < bb.right
          is_gutter = false
        end
      end
      vertical_gutters.push vertical_line if is_gutter
    end
    vertical_gutters.sort!
  end

  def self.get_horizontal_gutters(bounding_boxes)
    horizontal_lines  = bounding_boxes.collect{|bb| bb.top}
    horizontal_lines += bounding_boxes.collect{|bb| bb.bottom}
    horizontal_lines.uniq!

    horizontal_gutters = []
    horizontal_lines.each do |horizontal_line|
      is_gutter = true
      bounding_boxes.each do |bb|
        if bb.top < horizontal_line and horizontal_line < bb.bottom
          is_gutter = false
        end
      end
      horizontal_gutters.push horizontal_line if is_gutter
    end
    horizontal_gutters.sort!
  end

  def self.get_grouping_boxes(layers)

    # All layer boundaries to get the gutters
    bounding_boxes = layers.collect {|layer| layer.bounds}

    # Get the vertical and horizontal gutters at this level
    vertical_gutters   = get_vertical_gutters bounding_boxes
    horizontal_gutters = get_horizontal_gutters bounding_boxes
    Log.debug "Vertical Gutters: #{vertical_gutters}"
    Log.debug "Horizontal Gutters: #{horizontal_gutters}"

    # if empty gutters, then there probably is no children here.
    # TODO: Find out if this even happens?
    if vertical_gutters.empty? or horizontal_gutters.empty?
      return []
    end

    # get all possible grouping boxes with the available gutters
    grouping_boxes = []

    trailing_horizontal_gutters = horizontal_gutters
    leading_horizontal_gutters  = horizontal_gutters.rotate

    trailing_vertical_gutters = vertical_gutters
    leading_vertical_gutters  = vertical_gutters.rotate

    horizontal_bounds = trailing_horizontal_gutters.zip leading_horizontal_gutters
    vertical_bounds   = trailing_vertical_gutters.zip leading_vertical_gutters

    horizontal_bounds.pop
    vertical_bounds.pop

    root_group = Group.new Constants::GRID_ORIENT_NORMAL
    horizontal_bounds.each do |horizontal_bound|
      row_group = Group.new Constants::GRID_ORIENT_LEFT
      vertical_bounds.each do |vertical_bound|
        row_group.push BoundingBox.new horizontal_bound[0], vertical_bound[0], horizontal_bound[1], vertical_bound[1]
      end
      root_group.push row_group
    end

    Log.debug root_group
    return root_group
  end

  # Usually any layer that matches the grouping box's bounds is a style layer
  def self.get_style_layers(layers, is_leaf, parent_box = nil)
    style_layers = []
    
    if not parent_box.nil?

      if parent_box.class.to_s == "BoundingBox"
        max_bounds = parent_box
      else
        max_bounds = parent_box.bounds
      end

      style_layers = layers.select { |layer|
        layer.bounds == max_bounds and 
        (layer.kind == Layer::LAYER_SOLIDFILL or 
          layer.kind == Layer::LAYER_NORMAL or 
          (layer.kind == Layer::LAYER_SMARTOBJECT and not is_leaf)
        )
      }.flatten
    end

    return style_layers
  end
  
  def depth
    depth = 0
    parent = self.parent
    while (not parent.nil?)
      parent = parent.parent
      depth = depth + 1
    end
    
    depth
  end
  
  def set(layers, parent)
    layers.each { |layer| self.layers.push layer }

    self.parent = parent   # Parent grid for this grid
    
    if self.parent == nil
      Log.info "Setting the root node"
      self.root = true
      @@pageglobals.grouping_queue.push self
    end
    
    self.layers.sort!
    self.save!
  end
  
  def set_width_class
    if not self.bounds.nil?
      # Add a buffer of (960 + 10), because setting width of 960 in photoshop
      # is giving 962 in extendscript json. Debug more.
      if self.bounds.width != 0 and self.bounds.width <= 970
          self.width_class = PhotoshopItem::StylesHash.get_bootstrap_width_class(self.bounds.width)
      end
    end
  end
  
  def inspect
    "Style Layers: #{@layers.to_a}"
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
    
  def add_style_layers(grid_style_layers)
    if grid_style_layers.class.to_s == "Array"
      grid_style_layers.flatten!
      grid_style_layers.each { |style_layer| self.style_layers.push style_layer.id.to_s }
    else 
      self.style_layers.push grid_style_layers.id.to_s
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

  # Finds out intersecting nodes in lot of nodes
  def get_intersecting_nodes(nodes_in_region)
    
    intersect_found = false
    intersect_node_left = intersect_node_right = nil
    nodes_in_region.each do |node_left|
      nodes_in_region.each do |node_right|
        if node_left != node_right and node_left.intersect? node_right and !(node_left.encloses?(node_right) or node_right.encloses?(node_left))
          
          intersect_found = true
          intersect_node_right = node_right
          intersect_node_left  = node_left
          break
        end
      end
      break if intersect_found
    end
    
    return {:left => intersect_node_left, :right => intersect_node_right}
  end
  
  # Figures out whether two Layers are worth croppable.
  # Crop only if any one of them is enclosed in another for more than
  # 90%
  def could_intersect_be_cropped?(intersecting_nodes)
    left  = intersecting_nodes[:left]
    right = intersecting_nodes[:right]
    
    intersect_area = left.intersect_area(right)
    intersect_percent_left = (intersect_area * 100.0) / Float(left.bounds.area)
    intersect_percent_right = (intersect_area * 100.0) / Float(right.bounds.area)
    
    (intersect_percent_left > 90 or intersect_percent_right > 90)
  end
  
  # :left and :right are just conventions here. They don't necessarily 
  # depict their positions.
  def crop_smaller_intersect(intersecting_nodes)
    smaller_node = intersecting_nodes[:left]
    bigger_node  = intersecting_nodes[:right]
    if intersecting_nodes[:left].bounds.area > intersecting_nodes[:right].bounds.area
      smaller_node = intersecting_nodes[:right]
      bigger_node  = intersecting_nodes[:left]
    end
    
    new_bound = BoundingBox.new(smaller_node.bounds.top, 
      smaller_node.bounds.left, smaller_node.bounds.bottom,
      smaller_node.bounds.right).crop_to(bigger_node.bounds)
    
    smaller_node.bounds = new_bound
    
    {:left => smaller_node, :right => bigger_node}
  end

  def get_subgrids
    Log.debug "Getting subgrids (#{self.layers.length} layers in this grid)"
    
    # Some root grouping of nodes to recursivel add as children
    root_group = Grid.get_grouping_boxes self.layers
    Log.debug "Root groups #{root_group}"

    # list of layers in this grid.
    itr_layers           = self.layers
    initial_layers_count = itr_layers.size
    available_nodes      = Hash[itr_layers.collect { |item| [item.uid, item] }]
        
    # Get all the styles nodes at this level. These are the nodes that enclose every other nodes in the group
    root_style_layers = Grid.get_style_layers itr_layers, self.is_leaf?, root_group
    Log.info "Root style layers are #{root_style_layers}" if root_style_layers.size > 0
    Log.debug "Root style layers are #{root_style_layers}"

    # First add them as style layers to this grid
    self.add_style_layers root_style_layers

    # next remove them from the available_layers to process
    Log.debug "Deleting #{root_style_layers} root style layers..."
    root_style_layers.each { |root_style_layer| available_nodes.delete root_style_layer.uid}

    root_group.children.each do |row_group|
      current_layers = available_nodes.values

      row_layers = current_layers.select { |layer| row_group.bounds.encloses? layer.bounds }
      if row_layers.empty?
        next
      end
      
      row_grid = Grid.new :design => self.design
      row_grid.set [], self

      row_grid.orientation = Constants::GRID_ORIENT_LEFT
      
      row_style_layers = Grid.get_style_layers row_layers, self.is_leaf?, row_group
      Log.info "Row style layers are #{row_style_layers}" if row_style_layers.size > 0
      Log.debug "Row style layers are #{row_style_layers}"

      # Add them to row grid style layers and remove from available_layers
      row_grid.add_style_layers row_style_layers

      Log.debug "Deleting #{row_style_layers} row style layers..."
      row_style_layers.each {|layer| available_nodes.delete layer.uid}

      row_group.children.each do |grouping_box|
        remaining_nodes = available_nodes.values
        Log.debug "Trying grouping box #{grouping_box}"
        nodes_in_region = BoundingBox.get_objects_in_region grouping_box, remaining_nodes, :bounds

        style_layers = Grid.get_style_layers remaining_nodes, self.is_leaf?, grouping_box
        Log.info "Style layers are #{style_layers}" if style_layers.size > 0

        if nodes_in_region.empty?
          Log.info "Found padding region"
          @@pageglobals.padding_prefix_buffer = grouping_box.clone
          @@pageglobals.padding_boxes.push(grouping_box.clone)
          @@pageglobals.padding_boxes.uniq!
          
        elsif nodes_in_region.size <= initial_layers_count
          Log.info "Recursing inside, found #{nodes_in_region.size} nodes in region"
          if nodes_in_region.size == initial_layers_count
            # Case when layers are intersecting each other.
            
            intersecting_nodes = get_intersecting_nodes nodes_in_region
            
            # Remove all intersecting nodes first.
            available_nodes.delete intersecting_nodes[:left][:uid]
            available_nodes.delete intersecting_nodes[:right][:uid]
            nodes_in_region.delete intersecting_nodes[:left]
            nodes_in_region.delete intersecting_nodes[:right]
            
            # Check if there is any error in which a node is almost inside,
            # but slightly edging out. Crop out that edge.
            if could_intersect_be_cropped? intersecting_nodes
              new_intersecting_nodes = crop_smaller_intersect intersecting_nodes
              
              new_intersecting_nodes.each do |position, node_item|
                nodes_in_region.push node_item
                available_nodes[node_item[:uid]] = node_item
              end
              
            end
            
          end
          
          nodes_in_region.each {|node| available_nodes.delete node.uid}
          grid = Grid.new :design => self.design
          grid.set nodes_in_region, row_grid
          
          style_layers.each do |style_layer|
            Log.debug "Style node: #{style_layer.name}"
            grid.add_style_layers style_layer
            available_nodes.delete style_layer.uid
          end
          
          if not @@pageglobals.padding_prefix_buffer.nil?
           grid.offset_bounding_box = @@pageglobals.padding_prefix_buffer.clone
           @@pageglobals.reset_padding_prefix
          end
          
          @@pageglobals.grouping_queue.push grid
        end
      end
      
      if row_grid.children.size == 1
        subgrid        = row_grid.children.first
        subgrid.parent = self
        row_grid.delete
      end
    end
    self.save!
  end

  def tag
    if self.root
      :body
    else
      :div
    end
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
  
  
  # If the position of the element is > 0 and it is stacked up, calculate relative margin, not absolute margin from the Bounding box.
  # Similar stuff for left margin as well.
  def relative_margin
    
    if not @relative_margin
      margin_top  = (self.bounds.top - self.parent.bounds.top)
      margin_left = (self.bounds.left - self.parent.bounds.left)
      
      parent.children.each do |child|
        break if child == self
        next if child.bounds.nil?
        
        if parent.orientation == Constants::GRID_ORIENT_NORMAL
          margin_top -= (child.bounds.height + child.relative_margin[:top]) 
        else
          margin_left -= (child.bounds.width + child.relative_margin[:left])
        end
      end
          
      @relative_margin = { :top => margin_top, :left => margin_left }
    end
    
    @relative_margin
  end
  
  
  # Find out bounding box difference from it and its child.
  # Assumption is that it has only one child
  def padding_from_child
    child = children.first
    spacing = {}
    
    if bounds and child.bounds
      debugger
      spacing[:top]  = (child.bounds.top  - bounds.top)
      spacing[:left] = (child.bounds.left - bounds.left)
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
    padding = { :top => 0, :left => 0 }
    css     = {}
    
    if self.children.length > 0
      Log.info "#{self.id.to_s}'s kids"
      self.children.each do |child|
        Log.info "#{self.id.to_s} -> #{child.id.to_s}"
      end
      Log.info "#{self.children.length} kids"
      Log.info "My bound #{self.bounds}"
      debugger
      Log.info "My kid bound #{self.children.first.bounds}"
    end
    
    Log.info "#{self.id.to_s}'s parents"
    if self.parent and self.parent.parent
      Log.info "#{self.id.to_s} <- #{self.parent.id.to_s} <- #{self.parent.parent.id.to_s}"
      Log.info "My parent bound #{self.parent.bounds}"
      Log.info "My bound #{self.bounds}"
      
    end
    
    if not parent.nil? and not parent.bounds.nil? and not bounds.nil?
      
      # Guess work. For toplevel page wraps, the left margins are huge
      # and it is the first node in the grid tree
      is_top_level_page_wrap = ( parent.bounds.left == 0 and
        parent.parent == nil and
        relative_margin[:left] > 200 )
        
      
      if parent.children.length > 1
        if parent.bounds.left < bounds.left and !is_top_level_page_wrap
          margin[:left] += relative_margin[:left]
        end 
        
        if parent.bounds.top < bounds.top
          margin[:top]  += relative_margin[:top]
        end
      end
      
    end
    
    css[:'margin-left']  = "#{margin[:left]}px"  if margin[:left]  > 0
    css[:'margin-top']   = "#{margin[:top]}px"   if margin[:top]   > 0
    css[:'padding-left'] = "#{padding[:left]}px" if padding[:left] > 0
    css[:'padding-top']  = "#{padding[:top]}px"  if padding[:top]  > 0
    
    css
  end
  
  # For css
  # FIX Rename this function
  def buffer_margin
    buffer_margin = {:top => 0, :left => 0}
    
    if not self.offset_bounding_box.nil?
      if self.bounds.top - self.offset_bounding_box.top > 0
        buffer_margin[:top] = ( self.bounds.top - self.offset_bounding_box.top)
      end
      
      if self.bounds.left - self.offset_bounding_box.left > 0
        buffer_margin[:left] = (self.bounds.left - self.offset_bounding_box.left)
      end
      
    end
    
    buffer_margin
  end
  
  
  # De-serializes the offset box from mongo data.
  def offset_bounding_box
    if not self.offset_box.empty? 
      return BoundingBox.new(offset_box[0], offset_box[1], offset_box[2], offset_box[3])
    else
      return nil
    end
  end
  
  # Offset box is a box, that is an empty grid that appears before
  # this current grid. The previous sibling being a empty box, it adds itself
  # to a buffer. And the next item picks it up from buffer and takes it as its 
  # own offset bounding box.
  #
  # This function is for serializing bounding box and storing it.
  def offset_bounding_box=(padding_bound_box)
    self.offset_box = [padding_bound_box.top, padding_bound_box.left,
       padding_bound_box.bottom, padding_bound_box.right]
  end
  
  def is_single_line_text
    if not self.render_layer.nil?
      render_layer_obj = Layer.find self.render_layer
      
      if render_layer_obj.kind == Layer::LAYER_TEXT and
        not render_layer_obj.has_newline?
  
        return true
      else
        return false
      end
    else
      return false
    end
  end
  
  # If the width has already not been set, set the width.
  # TODO Find out if there is any case when width is set.
  def width_css(css)
    if self.fit_to_grid and self.depth < 5
      set_width_class
    elsif not css.has_key? :width
      if not is_single_line_text and
        not self.bounds.nil? and 
        self.bounds.width != 0
        
        return {:width => self.bounds.width.to_s + 'px'}
      end
    end
    
    return {}
  end
  
  def css_properties
    if self.css_hash.empty?
      css = {}
      self.style_layers.each do |layer_id|
        layer = Layer.find layer_id
        css.update layer.get_css({}, self.is_leaf?, self.root)
      end
      
      css.update width_css(css)
      css.delete :width if is_single_line_text

      # Set float.
      if not self.parent.nil? and  
        self.parent.orientation == Constants::GRID_ORIENT_LEFT
        
        css[:float] = 'left'
      end
      
      # Gives out the values for spacing the box model.
      # Margin and padding
      css.update spacing_css
      
      
      self.css_hash.update css
      
      if self.parent and self.parent.children.length == 1
        Log.error "Only one child for "
        Log.error "#{self.to_s}"
        Log.error "Children type:"
        Log.error "#{self.children.to_a.to_s}"
        self.css_hash.update({:border => '1px solid #f00'})
      end
      
      self.save!
    end
    
    raw_properties = self.css_hash
    return raw_properties
  end
  
  def to_html(args = {})
    layers_style_class = PhotoshopItem::StylesHash.add_and_get_class CssParser::to_style_string self.css_properties
    
    css_classes = []
    
    css_classes.push layers_style_class if not layers_style_class.nil?
    css_classes.push "row" if self.orientation == Constants::GRID_ORIENT_LEFT
    css_classes.push self.width_class if not self.width_class.nil?
    
    css_class_string = css_classes.join " "
    
    # Is this required for grids?
    inner_html = args.fetch :inner_html, ''

    attributes = Hash.new
    attributes[:class]          = css_class_string if not css_class_string.nil?
    attributes[:"data-grid-id"] = self.id.to_s
    
    sub_grid_args = Hash.new
    if self.render_layer.nil?
      child_nodes = self.children.sort { |a, b| a.id.to_s <=> b.id.to_s }
      child_nodes.each do |sub_grid|
        inner_html += sub_grid.to_html sub_grid_args
      end
      if not self.children.empty? and self.orientation == "left"
        inner_html += content_tag :div, " ", { :style => "clear: both" }, false
      end
      if child_nodes.length > 0
        html = (content_tag tag, inner_html, attributes, false)
      else
        html = ''
      end
    else
      sub_grid_args.update attributes
      render_layer_obj = Layer.find render_layer, sub_grid_args
      inner_html += render_layer_obj.to_html sub_grid_args, self.is_leaf?
      
      html = inner_html
    end
    
    return html
  end
  
  def to_s
    "Grid #{@bounds}"
  end
end