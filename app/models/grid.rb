class Grid
  attr_accessor :sub_grids, :parent, :bounds, :nodes
  def initialize(nodes, parent)
    self.nodes = nodes
    pp nodes
    parent = parent
    node_bounds = nodes.collect {|node| node.bounds}
    self.bounds = BoundingBox.get_super_bounds(node_bounds)
    puts "Getting sub grids for Grid with bounds = #{self.bounds}"
    self.sub_grids = get_subgrids(nodes)
  end

  def get_vertical_gutters(bounding_boxes, super_bounds)
    vertical_lines = bounding_boxes.collect{|bb| bb.left}
    vertical_lines += bounding_boxes.collect{|bb| bb.right}
    vertical_lines.uniq!

    vertical_gutters = []
    vertical_lines.each do |vertical_line|
      is_gutter = true
      bounding_boxes.each do |bb|
        if bb.left < vertical_line and vertical_line < bb.right and !bb.same_as?(super_bounds)
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
        if bb.top < horizontal_line and horizontal_line < bb.bottom and !bb.same_as?(super_bounds)
          is_gutter = false
        end
      end
      horizontal_gutters.push horizontal_line if is_gutter
    end
    horizontal_gutters.sort!
  end

  #FIXME: See if this function could be broken down. Too long!
  def get_subgrids(nodes)
    subgrids = []
    bounding_boxes = nodes.collect {|node| node.bounds}
    super_bounds = BoundingBox.get_super_bounds(bounding_boxes)

    vertical_gutters = get_vertical_gutters(bounding_boxes, super_bounds)
    horizontal_gutters = get_horizontal_gutters(bounding_boxes, super_bounds)

    puts "Horizontal Gutters #{horizontal_gutters}"
    puts "Vertical Gutters #{vertical_gutters}"

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
        previous_y_gutter = y_gutter
      end
      previous_x_gutter = x_gutter
    end
    return subgrids
=begin
    # If the gutters are in one direction
    # This case is common at higher levels
    # Eg., Level 1 - Header, body footer - all separated by horizontal gutter
    # Level 2 - Body has a content area and a right of left nav - app separated by vertical gutter
    # and so on
    if (horizontal_gutters.empty? and not vertical_gutters.empty?) or (vertical_gutters.empty? and not horizontal_gutters.empty?)
      if not horizontal_gutters.empty?
        previous_gutter = super_bounds.top
        left_bound = super_bounds.left
        right_bound = super_bounds.right
        horizontal_gutters.each do |gutter|
          current_region = BoundingBox.new(previous_gutter, left_bound, gutter, right_bound)
          nodes_in_region = BoundingBox.get_objects_in_region(current_region, nodes, :bounds)
          if not nodes_in_region.empty?
            subgrids.push Grid.new(nodes_in_region, self)
          end
          previous_gutter = gutter
        end
      else
        previous_gutter = super_bounds.left
        top_bound = super_bounds.top
        bottom_bound = super_bounds.bottom
        vertical_gutters.each do |gutter|
          current_region = BoundingBox.new(top_bound, previous_gutter, bottom_bound, gutter)
          nodes_in_region = BoundingBox.get_objects_in_region(current_region, nodes, :bounds)
          if not nodes_in_region.empty?
            subgrids.push Grid.new(nodes_in_region, self)
          end
          previous_gutter = gutter
        end
      end
      puts "IF"
    # If there are gutters in both directions
    # The case is common in lower levels, where you find a mXn grid of elements.
    elsif (!horizontal_gutters.empty? && !vertical_gutters.empty?)
      previous_x_gutter = super_bounds.top
      horizontal_gutters.each do |x_gutter|
        previous_y_gutter = super_bounds.left
        vertical_gutters.each do |y_gutter|
          current_region = BoundingBox.new(previous_x_gutter, previous_y_gutter, x_gutter, y_gutter)
          nodes_in_region = BoundingBox.get_objects_in_region(current_region, nodes, :bounds)
          if not nodes_in_region.empty?
            subgrids.push Grid.new(nodes_in_region, self)
          end
          previous_y_gutter = y_gutter
        end
        previous_x_gutter = x_gutter
      end
      puts "ELSIF"
    end
    puts "Subgrids: #{subgrids.size}"
    return subgrids
=end
  end

  def print(indent_level=0)
    spaces = ""
    prefix = "|--"
    indent_level.times {|i| spaces+="  "}
    puts "#{spaces}#{prefix}#{self.bounds.to_s}"
    self.sub_grids.each do |subgrid|
      subgrid.print(indent_level+1)
    end
  end
end
