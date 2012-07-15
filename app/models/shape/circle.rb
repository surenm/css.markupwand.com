module Shape::Circle
  def self.parse layer, grid
    return CssParser::parse_box layer, grid
  end

  # Four points:
  # 1. Top-most
  # 2. Left-most
  # 3. Bottom-most
  # 4. Right-most
  # All of them should be curved on both axes
  #
  # For all pairs of consecutive points,
  # the right dir of the first point as well as the left dir of the second point
  # should be tangential to the circle and should be half the length of the side
  # of a square that could be formed with these two points as the diagonal.
  def self.my_type? path
    path_points = path.path_points
    fully_curved_points = path_points.select {|point| point.curved_on_both_ends?}

    if path_points.size != 4 or fully_curved_points.size != 4
      return false
    end

    path_points.each do |path_point|
      next_point = path_point.next
      prev_point = path_point.prev
      opposite_point = next_point.next
      if (path_point.point.distance_squared next_point.point) != (path_point.point.distance_squared opposite_point.point)/2 or
          (path_point.point.distance_squared next_point.point) != (path_point.point.distance_squared prev_point.point)
        return false
      end
      if not (path_point.handle_flat? and prev_point.handle_flat? and next_point.handle_flat?) or
          not (path_point.perpendicular? prev_point and path_point.perpendicular? next_point)
        return false
      end
    end
    return true
  end
end