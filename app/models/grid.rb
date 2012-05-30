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
  field :offset_box, :type => Array, :default => []
  field :fit_to_grid,  :type => Boolean, :default => true
  
  field :css_hash, :type => Hash, :default => {}
  field :override_css_hash, :type => Hash, :default => {}
  
  field :tag, :type => String, :default => :div
  field :override_tag, :type => String, :default => nil
  
  field :width_class, :type => String, :default => ''
  field :override_width_class, :type => String, :default => nil

  @@pageglobals    = PageGlobals.instance
  @@grouping_queue = Queue.new
  
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
    @@grouping_queue.clear
  end

  def self.group!
    while not @@grouping_queue.empty?
      grid = @@grouping_queue.pop
      grid.group!
    end
  end

  # Usually any layer that matches the grouping box's bounds is a style layer
  def self.extract_style_layers(grid, available_layers, parent_box = nil)
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
      layer.bounds == max_bounds and (layer.kind == Layer::LAYER_SOLIDFILL or layer.kind == Layer::LAYER_NORMAL or layer.renderable_image?)
    end

    Log.info "Style layers for Grid #{grid} are #{grid_style_layers}. Adding them to grid..." if style_layers.size > 0
    grid_style_layers.flatten!
    grid_style_layers.each { |style_layer| grid.style_layers.push style_layer.id.to_s }

    Log.debug "Deleting #{style_layers} from grid"
    grid_style_layers.each { |style_layer| available_layers.delete style_layer.uid}

    return available_layers
  end
  
  def depth
    depth = 0
    parent = self.parent
    while not parent.nil?
      parent = parent.parent
      depth = depth + 1
    end
    
    depth
  end
  
  def set(layers, parent)
    self.parent = parent
    
    # Spent close to fucking one day trying to debug this.
    # Just trying to access this self.layer once, helps avoiding redundant  
    # inserts into the same group.
    #
    # Just remove the Log.info line below, and code will start breaking.
    # Magic! 
    # Pro-tip: http://ryanbigg.com/2010/04/has_and_belongs_to_many-double-insert/#comment-36741
    
    Log.info self.layers.to_a
    layers.each { |layer| self.layers.push layer }
    self.layers.sort!
    self.save!
    
    @@grouping_queue.push self if self.root?
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
  def self.get_intersecting_nodes(nodes_in_region)
    
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
  def self.could_intersect_be_cropped?(intersecting_nodes)
    left  = intersecting_nodes[:left]
    right = intersecting_nodes[:right]
    
    intersect_area = left.intersect_area(right)
    intersect_percent_left = (intersect_area * 100.0) / Float(left.bounds.area)
    intersect_percent_right = (intersect_area * 100.0) / Float(right.bounds.area)
    
    (intersect_percent_left > 90 or intersect_percent_right > 90)
  end
  
  # :left and :right are just conventions here. They don't necessarily 
  # depict their positions.
  def self.crop_smaller_intersect(intersecting_nodes)
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
    
    # Some root grouping of nodes to recursive add as children
    root_grouping_box = BoundingBox.get_grouping_boxes self.layers
    Log.debug "Trying Root grouping box: #{root_grouping_box}"

    # list of layers in this grid
    available_nodes = Hash[self.layers.collect { |item| [item.uid, item] }]
    
    # extract out style layers and parse with remaining        
    available_nodes = Grid.extract_style_layers self, available_nodes, root_grouping_box

    root_grouping_box.children.each do |row_grouping_box|
      available_nodes = Grid.process_row_grouping_box self, row_grouping_box, available_nodes
    end
    
    self.save!
  end
  
  def self.process_row_grouping_box(root_grid, row_grouping_box, available_nodes)
    Log.debug "Trying row grouping box: #{row_grouping_box}"
    
    row_grid = Grid.new :design => root_grid.design, :orientation => Constants::GRID_ORIENT_LEFT
    row_grid.set [], root_grid
            
    available_nodes = Grid.extract_style_layers row_grid, available_nodes, row_grouping_box
    
    row_grouping_box.children.each do |grouping_box|
      available_nodes = Grid.process_grouping_box row_grid, grouping_box, available_nodes
    end
    
    row_grid.save!
    
    if row_grid.children.size == 1
      subgrid        = row_grid.children.first
      subgrid.parent = root_grid
      row_grid.delete
    end
    
    return available_nodes
  end
  
  def self.process_grouping_box(row_grid, grouping_box, available_nodes)
    Log.debug "Trying grouping box: #{grouping_box}"

    nodes_in_region = BoundingBox.get_objects_in_region grouping_box, available_nodes.values, :bounds
    
    if nodes_in_region.empty?
      Log.info "Found padding region"
      @@pageglobals.add_padding_box grouping_box
      
    elsif nodes_in_region.size <= available_nodes.size
      grid = Grid.new :design => row_grid.design
      style_layers = Grid.extract_style_layers grid, available_nodes, grouping_box
      
      Log.info "Recursing inside, found #{nodes_in_region.size} nodes in region"
      if nodes_in_region.size == available_nodes.size
        # Case when layers are intersecting each other.
    
        intersecting_nodes = self.get_intersecting_nodes nodes_in_region
        
        if not intersecting_nodes[:left].nil? and not intersecting_nodes[:right].nil?
          # Remove all intersecting nodes first.
          available_nodes.delete intersecting_nodes[:left][:uid]
          available_nodes.delete intersecting_nodes[:right][:uid]
          nodes_in_region.delete intersecting_nodes[:left]
          nodes_in_region.delete intersecting_nodes[:right]
        
          # Check if there is any error in which a node is almost inside,
          # but slightly edging out. Crop out that edge.
          if Grid.could_intersect_be_cropped? intersecting_nodes
            new_intersecting_nodes = Grid.crop_smaller_intersect intersecting_nodes
            new_intersecting_nodes.each do |position, node_item|
              nodes_in_region.push node_item
              available_nodes[node_item[:uid]] = node_item
            end
          end
        end
      end
      
      grid.set nodes_in_region, row_grid
      nodes_in_region.each {|node| available_nodes.delete node.uid}
                
      if not @@pageglobals.padding_prefix_buffer.nil?
        grid.offset_bounding_box = @@pageglobals.padding_prefix_buffer.clone
        @@pageglobals.reset_padding_prefix
      end
      
      # This grid needs to be called with sub_grids, push to grouping procesing queue
      @@grouping_queue.push grid
    end
    return available_nodes
  end

  def tag
    :div
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
    
    if not parent.nil? and not parent.bounds.nil? and not bounds.nil?
      
      # Guess work. For toplevel page wraps, the left margins are huge
      # and it is the first node in the grid tree
      is_top_level_page_wrap = ( parent.bounds.left == 0 and parent.parent == nil and relative_margin[:left] > 200 )
        
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
  
  # If the width has already not been set, set the width.
  # TODO Find out if there is any case when width is set.
  def width_css(css)
    if self.fit_to_grid and self.depth < 5
      set_width_class
    elsif not css.has_key? :width
      if not is_single_line_text and not self.bounds.nil? and self.bounds.width != 0
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
      if not self.parent.nil? and self.parent.orientation == Constants::GRID_ORIENT_LEFT
        css[:float] = 'left'
      end

      # Gives out the values for spacing the box model.
      # Margin and padding
      # css.update spacing_css

      # hack to make css non empty. Couldn't initialize css_hash as nil and check for nil condition
      css[:processed] = true
      
      self.css_hash.update css
      self.save!
    end
    
    # remove the processed entry hack
    raw_properties = self.css_hash.clone
    raw_properties.delete :processed
    return raw_properties
  end
  
  def to_html(args = {})
    html = ''
    layers_style_class = PhotoshopItem::StylesHash.add_and_get_class CssParser::to_style_string self.css_properties
    
    css_classes = []
    
    css_classes.push layers_style_class if not layers_style_class.nil?
    css_classes.push "row" if self.orientation == Constants::GRID_ORIENT_LEFT
    css_classes.push self.width_class if not self.width_class.nil?
    
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

      if not self.children.empty? and self.orientation == "left"
        inner_html += content_tag :div, " ", { :style => "clear: both" }, false
      end

      if child_nodes.length > 0
        html = content_tag tag, inner_html, attributes, false
      end
      
    else
      sub_grid_args.update attributes
      render_layer_obj = Layer.find self.render_layer
      inner_html += render_layer_obj.to_html sub_grid_args, self.is_leaf?

      html = inner_html
    end
    
    return html
  end
  
  def to_s
    "Grid #{@bounds}"
  end
end