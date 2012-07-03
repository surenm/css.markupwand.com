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
  field :orientation, :type => Symbol, :default => Constants::GRID_ORIENT_NORMAL
  field :root, :type => Boolean, :default => false
  field :render_layer, :type => String, :default => nil
  field :style_layers, :type => Array, :default => []
  field :positioned_layers, :type => Array, :default => []
  field :body_style_layers, :type => Array, :default => []
  
  field :css_properties, :type => String, :default => nil

  field :generated_css_classes, :type => String, :default => nil
  field :user_css_class_map, :type => String, :default => nil
  
  field :tag, :type => String, :default => :div
  field :override_tag, :type => String, :default => nil
  
  field :width_class, :type => String, :default => ''
  field :override_width_class, :type => String, :default => nil
  field :is_positioned, :type => Boolean, :default => false

  field :offset_box_buffer, :type => String, :default => nil
  field :offset_box_type, :type => Symbol, :default => :offset_box
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
  
  def get_label
    css_classes = [""] + self.get_css_classes
    css_classes_string = css_classes.join " ."
    "<div class='editable-grid'><span class='editable-tag'> #{self.tag} </span> <span class='editable-class'> #{css_classes_string} </span></div>"
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
      :tag         => self.tag,
      :width_class => self.width_class,
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
      Log.info "Just one layer #{self.layers.first} is available. Adding to the grid..."
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

    if grid_style_layers.size > 0
      Log.info "Style layers for Grid #{grid} are #{grid_style_layers}. Adding them to grid..." 
      grid_style_layers.flatten!
      grid_style_layers.each { |style_layer| grid.style_layers.push style_layer.id.to_s }
      grid.style_layers.uniq!

      Log.info "Deleting #{style_layers} from grid..."
      grid_style_layers.each { |style_layer| available_layers.delete style_layer.uid}
    end
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
    Log.info "Extracting style layers from root grid #{self}..."
    available_nodes = Grid.extract_style_layers self, available_nodes, parent_box
    
    # Some root grouping of nodes to recursive add as children
    root_grouping_box = BoundingBox.get_grouping_boxes available_nodes.values
    self.orientation = root_grouping_box.orientation
    self.save!

    Log.info "Trying Root grouping box: #{root_grouping_box}..."  
    root_grouping_box.children.each do |row_grouping_box|
      if row_grouping_box.kind_of? BoundingBox
        Log.info "No row grouping required. Just handling as a grouping box..."
        available_nodes = process_grouping_box self, row_grouping_box, available_nodes
      else
        available_nodes = process_row_grouping_box row_grouping_box, available_nodes
      end
    end
    
    if available_nodes.length > 0
      Log.warn "Ignored nodes (#{available_nodes}) in region #{self.bounds}" 
    end
    
    self.save!
  end
  
  # Get an atomic group within a row grouping box and process them one group at a time
  def process_row_grouping_box(row_grouping_box, available_nodes)
    Log.info "Trying row grouping box #{row_grouping_box}..."
    
    nodes_in_row_region = BoundingBox.get_nodes_in_region row_grouping_box.bounds, available_nodes.values

    row_grid       = Grid.new :design => self.design, :orientation => Constants::GRID_ORIENT_LEFT
    row_grid.depth = self.depth + 1
    row_grid.set nodes_in_row_region, self
    
    Log.info "Layers in this row group are #{nodes_in_row_region}."

    if nodes_in_row_region.empty?
      Log.info "Marking this grouping box as margin..."
      self.design.row_offset_box = row_grouping_box.bounds
    else
      Log.info "Extracting style layers out of the row grid #{row_grid}"
      available_nodes = Grid.extract_style_layers row_grid, available_nodes, row_grouping_box
    
      row_grouping_box.children.each do |grouping_box|
        available_nodes = process_grouping_box row_grid, grouping_box, available_nodes
      end
      
      # reset previous row group's offset box buffer. Don't carry over to the new row
      Log.info "Resetting previous row's offset box buffers..."
      self.design.reset_offset_box
      
      # if row grid offset is not nil, then set that as top margin for this row grid
      if not self.design.row_offset_box.nil?
        Log.info "Setting top margin for this row grid..."
        row_grid.offset_box_buffer = BoundingBox.pickle self.design.row_offset_box
        row_grid.offset_box_type   = :row_offset_box
        self.design.reset_row_offset_box
      end
      row_grid.save!
    end
    
    return available_nodes
  end
  
  # Process a grouping box atomically
  def process_grouping_box(row_grid, grouping_box, available_nodes)
    Log.info "Trying grouping box #{grouping_box}..."
    raw_grouping_box_layers = BoundingBox.get_nodes_in_region grouping_box, available_nodes.values, zindex
    
    Log.info "Checking for error intersections in layers #{raw_grouping_box_layers}"
    grouping_box_layers = Grid.fix_error_intersections raw_grouping_box_layers

    if grouping_box_layers.empty?
      Log.info "Empty grouping box. Adding to margin for next grid to pick it up..."
      self.design.add_offset_box grouping_box.clone
    elsif grouping_box_layers.size <= available_nodes.size
      grid = Grid.new :design => row_grid.design, :depth => row_grid.depth + 1
      
      # Reduce the set of nodes, remove style layers.
      Log.info "Extract style layers for this grid #{grid}..."
      available_nodes = Grid.extract_style_layers grid, available_nodes, grouping_box
        
      # If where are still intersecting layers, make them positioned layers and remove them
      Log.info "Handle intersections gracefully..."
      bounding_boxes = available_nodes.values.collect { |node| node.bounds }
      gutters_available = BoundingBox.grouping_boxes_possible? bounding_boxes
      if not gutters_available and available_nodes.size > 1
        Grid.extract_positioned_layers grid, grouping_box_layers
      end

      grid.set grouping_box_layers, row_grid
      grouping_box_layers.each { |layer| available_nodes.delete layer.uid }
            
      if not self.design.offset_box.nil?
        #Pickup spacing that the previous box allocated.
        grid.offset_box_buffer = BoundingBox.pickle self.design.offset_box
        grid.save!

        #Reset the space
        self.design.reset_offset_box
      end

      # This grid needs to be called with sub_grids, push to grouping procesing queue
      if gutters_available
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
            if node_left.bounds.area < node_right.bounds.area
              intersecting_node_pairs.push [node_left, node_right]
            else
              intersecting_node_pairs.push [node_right, node_left]
            end
          end
        end
      end
    end
    
    intersecting_node_pairs.uniq!
    Log.info "Intersecting layers found - #{intersecting_node_pairs}"
    return intersecting_node_pairs
  end
  
  def self.fix_error_intersections(layers_in_region)
    intersecting_pairs = Grid.get_intersecting_nodes layers_in_region
    
    intersecting_pairs.each do |intersecting_layers|
      intersect_area = intersecting_layers.first.intersect_area(intersecting_layers.second)
      intersect_percent_left = (intersect_area * 100.0) / Float(intersecting_layers.first.bounds.area)
      intersect_percent_right = (intersect_area * 100.0) / Float(intersecting_layers.second.bounds.area)
      
      corrected_layers = nil
      if intersect_percent_left > 90 or intersect_percent_right > 90
        is_error_intersection = true
        corrected_layers = Grid.crop_inner_intersect intersecting_layers
      elsif intersect_percent_left < 5 and intersect_percent_right < 5
        is_error_intersection = true
        corrected_layers = Grid.crop_outer_intersect intersecting_layers
      end
      
      if not corrected_layers.nil?
        Log.info "Correcting #{intersecting_layers}..."
        layers_in_region.delete intersecting_layers.first
        layers_in_region.delete intersecting_layers.second
        
        layers_in_region.push corrected_layers.first
        layers_in_region.push corrected_layers.second
      end
    end
    return layers_in_region
  end
  
  # :left and :right are just conventions here. They don't necessarily 
  # depict their positions.
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
  
  def self.extract_positioned_layers(grid, layers_in_region)
    intersecting_layer_pairs = Grid.get_intersecting_nodes layers_in_region
    return layers_in_region if intersecting_layer_pairs.empty?

    layers_bounds = layers_in_region.collect { |layer| layer.bounds }
    offset_bounds = BoundingBox.get_super_bounds layers_bounds

    intersecting_layers = intersecting_layer_pairs.flatten.uniq
    intersecting_layers.sort! { |layer1, layer2| layer2.bounds.area <=> layer1.bounds.area }

    flow_layers_in_region = [intersecting_layers.first]
    layers_in_region.each do |layer|
       if not intersecting_layers.include? layer
         flow_layers_in_region.push layer
       end
    end
    
    inner_grid = Grid.new :design => grid.design, :depth => grid.depth + 1
    inner_grid.set flow_layers_in_region, grid
    inner_grid.offset_box_buffer = BoundingBox.pickle offset_bounds
    inner_grid.save!
    @@grouping_queue.push inner_grid
    
    positioned_layers_in_region = layers_in_region - flow_layers_in_region
    
    positioned_layers_in_region.sort! { |layer1, layer2| layer2.zindex <=> layer1.zindex }
    positioned_layers_in_region.each do |layer|
      layers_in_grid   = BoundingBox.get_nodes_in_region layer.bounds, layers_in_region, layer.zindex
      layers_in_region = layers_in_region - layers_in_grid
      
      positioned_grid  = Grid.new :design => grid.design, :depth => grid.depth + 1, :is_positioned => true
      positioned_grid.set layers_in_grid, grid
      
      @@grouping_queue.push positioned_grid
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
  
  ## Spacing and padding related methods
   
  # Find out bounding box difference from it and its children.
  def padding_from_child
    non_style_layers = self.layers.to_a.select do |layer|
      not self.style_layers.to_a.include? layer.id.to_s
    end
    
    children_bounds = non_style_layers.collect { |layer| layer.bounds }
    children_superbound = BoundingBox.get_super_bounds children_bounds
    spacing = { :top => 0, :left => 0, :bottom => 0, :right => 0 }
    
    if not bounds.nil? and not children_superbound.nil?
      spacing[:top]     = (children_superbound.top  - bounds.top)
      spacing[:bottom]  = (bounds.bottom - children_superbound.bottom)

      spacing[:left]  = (children_superbound.left - bounds.left)
      spacing[:right] = (bounds.right - children_superbound.right )
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
  def offset_box_spacing
    offset_box_spacing = {:top => 0, :left => 0}
    if not self.offset_box_buffer.nil? and not self.offset_box_buffer.empty?
      offset_box_object = BoundingBox.depickle self.offset_box_buffer

      if self.offset_box_type == :offset_box
        if self.bounds.top - offset_box_object.top > 0
          offset_box_spacing[:top] = self.bounds.top - offset_box_object.top
        end

        if self.bounds.left - offset_box_object.left > 0 and 
          offset_box_spacing[:left] = self.bounds.left - offset_box_object.left
        end
      elsif self.offset_box_type == :row_offset_box
        # just the top margin for row offset box
        if self.bounds.top - offset_box_object.top > 0
          offset_box_spacing[:top] = self.bounds.top - offset_box_object.top
        end
      end
    end

    if self.root == true
      offset_box_spacing[:top]    += self.bounds.top
      offset_box_spacing[:left]   += self.bounds.left
    end
    
    offset_box_spacing
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
    if not css.has_key? :width and not is_single_line_text and not unpadded_width.nil? and unpadded_width != 0
        return {:width => unpadded_width.to_s + 'px'}
    end
    
    return {}
  end
  
  def get_css_properties
    if self.css_properties.nil?
      css = {}

      self.style_layers.each do |layer_id|
        layer = Layer.find layer_id
        css.update layer.get_css({}, self.is_leaf?, self)
      end
      
      css.update width_css(css)
      css.delete :width if is_single_line_text
      
      # Positioning
      positioned_grid_count = (self.children.select { |grid| grid.is_positioned }).length
      css[:position] = 'relative' if positioned_grid_count > 0
      
      css.update CssParser::position_absolutely(self) if is_positioned

      # Gives out the values for spacing the box model.
      # Margin and padding
      css.update spacing_css

      self.css_properties = css.to_json.to_s
      self.save!
    end

    css = JSON.parse self.css_properties, :symbolize_keys => true
    return css
  end
  
  def get_css_classes
    if self.generated_css_classes.nil?
      grid_style_class = StylesHash.add_and_get_class CssParser::to_style_string self.get_css_properties

      css_classes = []

      # Set pull-left.
      css_classes.push 'pull-left' if not self.parent.nil? and self.parent.orientation == Constants::GRID_ORIENT_LEFT
      css_classes.push grid_style_class if not grid_style_class.nil?

      self.generated_css_classes = css_classes.to_json.to_s
      self.save!
    end
    
    css_classes = JSON.parse self.generated_css_classes
    return css_classes
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
    
    css_classes      = self.get_css_classes
    css_class_string = css_classes.join " "
    
    attributes         = Hash.new
    attributes[:class] = css_class_string if not css_class_string.nil?
    attributes[:"data-grid-id"] = self.id.to_s
        

    if self.render_layer.nil?
      sub_grid_args = Hash.new
        
      child_nodes = self.children.select { |node| not node.is_positioned }
      child_nodes = child_nodes.sort { |a, b| a.id.to_s <=> b.id.to_s }
      child_nodes.each do |sub_grid|
        inner_html += sub_grid.to_html sub_grid_args
      end
      if not self.children.empty? and self.orientation == Constants::GRID_ORIENT_LEFT
        inner_html += content_tag :div, " ", { :style => "clear: both" }, false
      end
      
      inner_html += positioned_grids_html(sub_grid_args)
      
      if child_nodes.length > 0
        html = content_tag tag, inner_html, attributes, false
      end
      
    else
      sub_grid_args = attributes
      sub_grid_args[tag] = self.tag
      sub_grid_args[:inner_html] = self.positioned_grids_html

      render_layer_obj = Layer.find self.render_layer
      html = render_layer_obj.to_html sub_grid_args, self.is_leaf?, self
    end
    
    return html
  end
end