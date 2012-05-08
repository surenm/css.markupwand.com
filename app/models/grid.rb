class Grid
  attr_accessor :sub_grids, :parent, :bounds, :nodes, :gutter_type, :layer

  def initialize(nodes, parent)
    if parent.nil?
      Log.debug "Calling Root node"
    else
      Log.debug "Calling grid on #{parent.bounds}"
    end
    nodes.each do |node|
      Log.debug node
    end
    self.nodes = nodes
    self.parent = parent
    node_bounds = nodes.collect {|node| node.bounds}
    self.bounds = BoundingBox.get_super_bounds(node_bounds)
    self.sub_grids = get_subgrids(nodes)
    if self.parent == nil
      self.layer.is_a_root_node
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
    @photoshop_layers.push layer
  end
  end

  #FIXME: See if this function could be broken down. Too long!
  def get_subgrids(nodes)
    subgrids = []
    bounding_boxes = nodes.collect {|node| node.bounds}
    super_bounds   = BoundingBox.get_super_bounds(bounding_boxes)

    grid_overlays = nodes.select {|node| node.bounds == super_bounds}
    if not grid_overlays.empty?
      grid_overlays.each do |overlayed_node|
        self.add_photoshop_layer overlayed_node
        bounding_boxes.delete overlayed_node.bounds
        nodes.delete overlayed_node
      end
    end

    vertical_gutters   = get_vertical_gutters(bounding_boxes, super_bounds)
    horizontal_gutters = get_horizontal_gutters(bounding_boxes, super_bounds)
    #Log.debug "Vertical Gutters: #{vertical_gutters}"
    #Log.debug "Horizontal Gutters: #{horizontal_gutters}"

    # get all possible grouping boxes with the available gutters
    grouping_boxes = []
    horizontal_gutters.repeated_combination(2).each do |x_gutters|
      vertical_gutters.repeated_combination(2).each do |y_gutters|
        grouping_boxes.push BoundingBox.new x_gutters[0], y_gutters[0], x_gutters[1], y_gutters[1]
      end
    end
    
    # sort them on the basis of area in decreasing order
    grouping_boxes.sort! { |a, b| b.area <=> a.area }
    
    # list of nodes to exhaust
    available_nodes = Hash.new
    nodes.each do |node| 
      available_nodes[node.uid] = node
    end
    
    grouping_boxes.each do |grouping_box|
      break if available_nodes.empty?
      remaining_nodes = available_nodes.values
      
      nodes_in_region = BoundingBox.get_objects_in_region grouping_box, remaining_nodes, :bounds
      
      if not nodes_in_region.empty? and nodes_in_region.size < nodes.size
        nodes_in_region.each {|node| available_nodes.delete node.uid}
        subgrids.push Grid.new(nodes_in_region, self)
      end
      
    end

    return subgrids
  end

  def print(indent_level=0)
    spaces = ""
    prefix = "|--"
    indent_level.times {|i| spaces+="  "}
    puts "#{spaces}#{prefix}#{self.bounds.to_s}#{self.nodes.to_s}"
    self.sub_grids.each do |subgrid|
      subgrid.print(indent_level+1)
    end
  end

  def to_html
    html = ""
    if self.sub_grids.empty?
      html = self.layer.to_html
    else
      self.sub_grids.each do |subgrid|
        html += subgrid.to_html
      end
      html = self.layer.to_html({:inner_html=>html})
    end
    return html
  end
end
