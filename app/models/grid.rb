class Grid
  include ActionView::Helpers::TagHelper
  attr_accessor :sub_grids, :parent, :bounds, :nodes, :gutter_type, :layer

  def initialize(nodes, parent, max_depth = 100)

    @nodes     = nodes    # The layers enclosed by this Grid
    @parent    = parent   # Parent grid for this grid
    @layers    = []       # Set of children style layers for this grid
    @sub_grids = []       # children for this grid

    @is_root   = false    # if the grid is the root node or the <body> tag for this html
    if @parent == nil
      @is_root = true
    end
    
    node_bounds = nodes.collect {|node| node.bounds}
    @bounds = BoundingBox.get_super_bounds node_bounds
    
    @nodes.sort!
    
    if @nodes.size > 1 
      if max_depth > 0
        @sub_grids = get_subgrids max_depth
      else 
        Log.fatal "Recursive parsing stopped because max_depth has been reached"
      end
    elsif @nodes.size == 1
      @sub_grids.push @nodes.first  # Trivial. Just one layer is a child of this layer
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

  def add_photoshop_layer(layer)
    @layers.push layer
  end
  
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
    
    horizontal_bounds.each do |horizontal_bound|
      vertical_bounds.each do |vertical_bound|
        grouping_boxes.push BoundingBox.new horizontal_bound[0], vertical_bound[0], horizontal_bound[1], vertical_bound[1]
      end
    end
    
    # sort them on the basis of area in decreasing order
    grouping_boxes.sort! { |a, b| b.area <=> a.area }
    
    return grouping_boxes
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
      flag
    end
    
    return super_nodes
  end

  #FIXME: See if this function could be broken down. Too long!
  def get_subgrids(max_depth)
    subgrids = [] 
    
    super_nodes = Grid.get_super_nodes @nodes

    super_nodes.each do |super_node|
      Log.debug "Style node: #{super_node}"
      self.add_photoshop_layer super_node
      nodes.delete super_node
    end
    
    bounding_boxes = nodes.collect {|node| node.bounds}
    super_bounds   = BoundingBox.get_super_bounds bounding_boxes

    vertical_gutters   = get_vertical_gutters bounding_boxes, super_bounds
    horizontal_gutters = get_horizontal_gutters bounding_boxes, super_bounds

    Log.debug "Vertical Gutters: #{vertical_gutters}"
    Log.debug "Horizontal Gutters: #{horizontal_gutters}"
    
    if vertical_gutters.empty? or horizontal_gutters.empty? 
      return []
    end

    grouping_boxes = Grid.get_grouping_boxes horizontal_gutters, vertical_gutters
    
    # list of nodes to exhaust. A slick way to construct a hash from array
    available_nodes = Hash[nodes.collect { |item| [item.uid, item] }]
    
    grouping_boxes.each do |grouping_box|
      break if available_nodes.empty?
      remaining_nodes = available_nodes.values

      nodes_in_region = BoundingBox.get_objects_in_region grouping_box, remaining_nodes, :bounds
      
      if nodes_in_region.empty?
        # TODO: This grouping box denotes padding or white space between two regions. Handle that. 
        # Usually a corner case
      elsif nodes_in_region.size == nodes.size
        # TODO: This grouping_box is a superbound of thes nodes. 
        # Add this as a style to the grid if there exists a layer for this grouping_box
      elsif nodes_in_region.size < nodes.size
        nodes_in_region.each {|node| available_nodes.delete node.uid}
        subgrids.push Grid.new nodes_in_region, self, max_depth - 1
      end
    end
    
    subgrids.each do |grid|
      Log.fatal grid
    end

    return subgrids
  end

  def print(indent_level=0)
    spaces = ""
    prefix = "|--"
    indent_level.times {|i| spaces+="  "}

    puts "#{spaces}#{prefix}#{self.bounds.to_s}"
    self.nodes.each do |node|
      puts "#{spaces}#{spaces}#{node}"
    end
    self.sub_grids.each do |subgrid|
      indent_level += 4
      subgrid.print(indent_level+1)
      indent_level -= 4
    end
  end
  
  def inspect
    if @sub_grids.nil?
      Log.debug "Empty subgrids"
      return
    end
    
    @sub_grids.each do |grid|
      Log.debug grid
    end
  end

  def to_html
    html = ""
    @photoshop_layers.each do |photoshop_layer| 
      html += photoshop_layer.to_html
    end
    
    if not @sub_grids.nil? and not @sub_grids.empty?
      @sub_grids.each do |subgrid|
        html += subgrid.to_html
      end
    end
    return html
  end
end
