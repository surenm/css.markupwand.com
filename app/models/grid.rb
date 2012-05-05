class Grid
  attr_accessor :sub_grids, :parent, :bounds

  def initialize(nodes, parent)
    parent = parent
    bounds = BoundingBox.get_super_bounds(nodes)
    self.sub_grids = get_subgrids(nodes)
  end

  #FIXME: See if this function could be broken down. Too long!
  def get_subgrids(nodes)
    subgrids = []
    bounding_boxes = nodes.collect {|node| node.bounds}
    super_bounds = BoundingBox.get_super_bounds(nodes)

    vertical_lines = bounding_boxes.collect{|bb| bb.left}
    vertical_lines += bounding_boxes.collect{|bb| bb.right}
    vertical_lines.uniq!

    horizontal_lines = bounding_boxes.collect{|bb| bb.top}
    horizontal_lines += bounding_boxes.collect{|bb| bb.bottom}
    horizontal_lines.uniq!

    vertical_gutters = vertical_lines.select do |vertical_line|
      bounding_boxes.each do |bb|
        if bb.left < vertical_line and vertical_line < bb.right
          return false
        end
      end
      return true
    end

    horizontal_gutters = horizontal_lines.collect do |horizontal_line|
      bounding_boxes.each do |bb|
        if bb.top < horizontal_line and horizontal_line < bb.bottom
          return false
        end
      end
      return true
    end
    
    # If the gutters are in one direction - Most likely the case at higher levels
    if (horizontal_gutters.empty? and not vertical_gutters.empty?) or (vertical_gutters.empty? and not horizontal_gutters.empty?)
      if not horizontal_gutters.empty?
        previous_gutter = super_bounds.top
        left_bound = super_bounds.left
        right_bound = super_bounds.right
        horizontal_gutters.each do |gutter|
          current_region = BoundingBox.new(previous_gutter, left_bound, gutter, right_bound)
          nodes_in_region = BoundingBox.get_objects_in_region(current_region, nodes, :bounds)
          subgrids.push Grid.new(nodes_in_region, self)
        end
      else
        previous_gutter = super_bounds.left
        top_bound = super_bounds.top
        bottom_bound = super_bounds.bottom
        vertical_gutters.each do |gutter|
          current_region = BoundingBox.new(top_bound, previous_gutter, bottom_bound, gutter)
          nodes_in_region = BoundingBox.get_objects_in_region(current_region, nodes, :bounds)
          subgrids.push Grid.new(nodes_in_region, self)
        end
      end
    end
    
    # If there are gutters in both directions - The case in lower levels
    if (!horizontal_gutters.empty? && !vertical_gutters.empty?)
      horizontal_gutters.each do |x_gutter|
        vertical_gutters.each do |y_gutter|
          #TODO: Fill in the logic
        end
      end
    end
  end
end
