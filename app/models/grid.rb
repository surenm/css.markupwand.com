class Grid
  attr_accessor :sub_grids, :parent, :bounds

  def initialize(nodes, parent)
    parent = parent
    bounds = BoundingBox.get_super_bounds(nodes)
    self.sub_grids = get_subgrids(nodes)
  end

  def get_subgrids(nodes)
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
    
  end
end
