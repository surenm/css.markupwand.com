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

  def copy_layer_info(node)
    self.layer = node
  end

  #FIXME: See if this function could be broken down. Too long!
  def get_subgrids(nodes)
    subgrids = []
    bounding_boxes = nodes.collect {|node| node.bounds}
    super_bounds   = BoundingBox.get_super_bounds(bounding_boxes)

    grid_overlays = nodes.select {|node| node.bounds == super_bounds}
    if not grid_overlays.empty?
      grid_overlays.each do |overlayed_node|
        self.copy_layer_info overlayed_node
        bounding_boxes.delete overlayed_node.bounds
        nodes.delete overlayed_node
      end
    end


    vertical_gutters = get_vertical_gutters(bounding_boxes, super_bounds)
    horizontal_gutters = get_horizontal_gutters(bounding_boxes, super_bounds)

    horizontal_gutters.each_with_index do |x_gutter, x_index|
      next if x_index==0
      previous_x_gutter = horizontal_gutters[x_index-1]
      vertical_gutters.each_with_index do |y_gutter, y_index|
        next if y_index==0
        previous_y_gutter = vertical_gutters[y_index-1]
        current_region = BoundingBox.new(previous_x_gutter, previous_y_gutter, x_gutter, y_gutter)
        nodes_in_region = BoundingBox.get_objects_in_region(current_region, nodes, :bounds)
        if not nodes_in_region.empty?
          subgrids.push Grid.new(nodes_in_region, self)
        end
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
