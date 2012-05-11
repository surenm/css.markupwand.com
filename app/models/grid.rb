class Grid
  include ActionView::Helpers::TagHelper
  attr_accessor :sub_grids, :parent, :bounds, :nodes, :gutter_type, :layer, :orientation

  def self.get_grouping_boxes(horizontal_gutters, vertical_gutters)
    # get all possible grouping boxes with the available gutters
    grouping_boxes = []
    
    trailing_horizontal_gutters = horizontal_gutters
    leading_horizontal_gutters = horizontal_gutters.rotate
    
    trailing_vertical_gutters = vertical_gutters
    leading_vertical_gutters = vertical_gutters.rotate
    
    horizontal_bounds = trailing_horizontal_gutters.zip leading_horizontal_gutters
    vertical_bounds = trailing_vertical_gutters.zip leading_vertical_gutters
    
    horizontal_bounds.slice! -1
    vertical_bounds.slice! -1    
    
    root_group = Group.new :normal
    horizontal_bounds.each do |horizontal_bound|
      row_group = Group.new :left
      vertical_bounds.each do |vertical_bound|
        row_group.push BoundingBox.new horizontal_bound[0], vertical_bound[0], horizontal_bound[1], vertical_bound[1]
      end
      root_group.push row_group
    end
    return root_group
  end
  
  def self.get_super_nodes(nodes)
    super_nodes = nodes.select do |enclosing_node|
      flag = true
      nodes.each do |node|
        if not enclosing_node.encloses? node
          flag = false 
          break
        end
      end
      flag and enclosing_node.kind == PhotoshopItem::Layer::LAYER_SOLIDFILL
    end
    
    return super_nodes
  end

  def initialize(nodes, parent)
    @nodes     = nodes    # The layers enclosed by this Grid
    @parent    = parent   # Parent grid for this grid
    @layers    = []       # Set of children style layers for this grid
    @sub_grids = []       # children for this grid
    @orientation = :normal

    super_nodes = Grid.get_super_nodes @nodes

    super_nodes.each do |super_node|
      Log.debug "Style node: #{super_node.name}"
      self.add_photoshop_layer super_node
      nodes.delete super_node
    end

    @is_root = false    # if the grid is the root node or the <body> tag for this html
    
    if @parent == nil
      Log.debug "Setting the root node"
      @is_root = true
    end
    
    if nodes.empty?
      @bounds = nil
    else
      node_bounds = nodes.collect {|node| node.bounds}
      @bounds = BoundingBox.get_super_bounds node_bounds
      Log.debug "Super bound = #{@bounds.to_s}"
    end
    
    @nodes.sort!
  end
  
  def add_photoshop_layer(layer)
    @layers.push layer
  end
    
  def group(max_depth = 100)
    if @nodes.size > 1 
      if max_depth > 0
        @sub_grids = get_subgrids max_depth
      else 
        Log.fatal "Recursive parsing stopped because max_depth has been reached"
      end
    elsif @nodes.size == 1
      @sub_grids.push @nodes.first  # Trivial. Just one layer is a child of this layer
    end
    @sub_grids.each do |sub_grid|
      sub_grid.group if sub_grid.class.to_s == "Grid"
    end
  end

  def get_vertical_gutters(bounding_boxes, super_bounds)
    vertical_lines = bounding_boxes.collect{|bb| bb.left}
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

  def get_horizontal_gutters(bounding_boxes, super_bounds)
    horizontal_lines = bounding_boxes.collect{|bb| bb.top}
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
  
  def create_dummy_wrapper(bound)
    dummy_layer = Constants::dummy_layer_hash
    dummy_layer[:bounds][:value][:top][:value] = bound.top
    dummy_layer[:bounds][:value][:left][:value] = bound.left
    dummy_layer[:bounds][:value][:bottom][:value] = bound.bottom
    dummy_layer[:bounds][:value][:right][:value] = bound.right
    
    PhotoshopItem::Layer.new dummy_layer
  end

  def get_subgrids(max_depth)
    subgrids = [] 
    Log.info "Getting subgrids (#{nodes.length} nodes in this grid)"
    Log.info "#{nodes.join ','}"
    
    bounding_boxes = nodes.collect {|node| node.bounds}
    Log.info "Bounding boxes - #{bounding_boxes}"
    super_bounds   = BoundingBox.get_super_bounds bounding_boxes
    Log.info "Super bound - #{super_bounds}"
    
    vertical_gutters   = get_vertical_gutters bounding_boxes, super_bounds
    horizontal_gutters = get_horizontal_gutters bounding_boxes, super_bounds

    Log.debug "Vertical Gutters: #{vertical_gutters}"
    Log.debug "Horizontal Gutters: #{horizontal_gutters}"
    
    if vertical_gutters.empty? or horizontal_gutters.empty? 
      return []
    end

    root_group = Grid.get_grouping_boxes horizontal_gutters, vertical_gutters
    
    # list of nodes to exhaust. A slick way to construct a hash from array
    available_nodes = Hash[nodes.collect { |item| [item.uid, item] }]
    
    Log.info "Root groups #{root_group}"
    root_group.children.each do |row_group|
      row_grid = Grid.new [], self
      row_grid.orientation = row_group.orientation
      row_group.children.each do |grouping_box|
        remaining_nodes = available_nodes.values
        Log.info "Trying grouping box #{grouping_box}"
        nodes_in_region = BoundingBox.get_objects_in_region grouping_box, remaining_nodes, :bounds
        if nodes_in_region.empty?
          Log.info "Stopping, no more nodes in this region"
          # TODO: This grouping box denotes padding or white space between two regions. Handle that. 
          # Usually a corner case
        elsif nodes_in_region.size == nodes.size
          Log.info "Stopping, no nodes were reduced"
          # TODO: This grouping_box is a superbound of thes nodes. 
          # Add this as a style to the grid if there exists a layer for this grouping_box
          # Sometimes there is no parent layer for this grouping box, when two big layers are interesecting for applying filters.
        elsif nodes_in_region.size < nodes.size
          Log.info "Recursing inside, found nodes in region"
          nodes_in_region.each {|node| available_nodes.delete node.uid}
          grid = Grid.new nodes_in_region, self
          row_grid.sub_grids.push grid
        end
      end
      subgrids.push row_grid
    end

    return subgrids
  end

  def print(indent_level=0)
    spaces = ""
    prefix = "|--"
    indent_level.times {|i| spaces+=" "}

    puts "#{spaces}#{prefix} (grid) #{self.bounds.to_s}"
    self.sub_grids.each do |subgrid|
      indent_level += 1
      subgrid.print(indent_level+1)
      indent_level -= 1
    end
    
  end
  
  def tag
    if @is_root
      :body
    else
      :div
    end
  end
  
  def to_html(args = {})
    #puts "Generating html for #{self.inspect}"
    css = args.fetch :css, {}
    css_class = PhotoshopItem::StylesHash.add_and_get_class Converter::to_style_string css

    @layers.each do |layer|
      css.update layer.get_css({}, @is_root)
    end

    # Is this required for grids?
    inner_html = args.fetch :inner_html, ''
  
    attributes = Hash.new
    attributes[:class] = css_class if not css_class.nil?
    
    children_override_css = Hash.new
    if @orientation == :left
      children_override_css[:float] = 'left' 
    end

    sub_grid_args = Hash.new
    sub_grid_args[:css] = children_override_css
    
    @sub_grids.each do |sub_grid|
      inner_html += sub_grid.to_html sub_grid_args
    end
    
    if @sub_grids.empty? and @orientation == :left
      inner_html += content_tag :div, " ", { :style => "clear: both" }, false
    end
    
    html = content_tag tag, inner_html, attributes, false
    return html
  end
end
