module Shape::Box

  def self.curves_balanced?(path_segments)
    # Ideally should check if none of the segments are not suitable for a standard box.
    # Reserving for later, and looking at whether curves are balanced alone.
    # The concave/convex logic isn't perfectly right. Won't work for cases where
    # one segment would form the entire curved side(with a large border radius) of a button
    path_segments.each_with_index do |segment, i|
      pair_index = (i+(path_segments.size/2))%path_segments.size
      pair_segment = path_segments[pair_index]
      next_segment = path_segments[(i+1)%path_segments.size]
      previous_segment = path_segments[(i+path_segments.size-1)%path_segments.size]
      pair_next_segment = path_segments[(pair_index+1)%path_segments.size]
      pair_previous_segment = path_segments[(pair_index+path_segments.size-1)%path_segments.size]

      if  (segment.straight? and not pair_segment.straight?) or
          (segment.curved_x? and not pair_segment.curved_x?) or
          (segment.curved_y? and not pair_segment.curved_y?)
        return false
      end

      # Also check if the non-boxy points' previous and next points are such that the shape doesn't have any cave-ins.
      # Caved-in shapes can't be handled with CSS. So, image has to be generated.
      if not (segment.curved_at_one_end? or segment.straight?)
        if not segment.parallel? pair_segment
          return false
        end
        if segment.curved_x?
          if segment.y < pair_segment.y
            if not (segment.y < previous_segment.y and segment.y < next_segment.y and pair_segment.y > pair_previous_segment.y and pair_segment.y > pair_next_segment.y)
              return false
            end
          elsif segment.y > pair_segment.y
            if not (segment.y > previous_segment.y and segment.y > next_segment.y and pair_segment.y < pair_previous_segment.y and pair_segment.y < pair_next_segment.y)
              return false
            end
          end
        elsif segment.curved_y?
          if segment.x < pair_segment.x
            if not (segment.x < previous_segment.x and segment.x < next_segment.x and pair_segment.x > pair_previous_segment.x and pair_segment.x > pair_next_segment.x)
              return false
            end
          elsif segment.x > pair_segment.x
            if not (segment.x > previous_segment.x and segment.x > next_segment.x and pair_segment.x < pair_previous_segment.x and pair_segment.x < pair_next_segment.x)
              return false
            end
          end
        end
      end
    end
    return true
  end

  def self.parse(layer, grid)
    return CssParser.parse_box layer, grid
  end

  # Use a whitelist of box patterns instead of a generic pattern
  def self.my_type?(path)
    path_points = path.path_points

    # Regular rectangles with sharp edges, and Lines
    # Consecutive points would have the same value on only one of the axes
    # and that axis would be different for consecutive pairs
    # Handle length should be 0 for all points
    if path_points.size == 4
      path_points.each do |path_point|
        prev_point = path_point.prev
        next_point = path_point.next
        unless path_point.handle_none? and prev_point.handle_none? and next_point.handle_none?
          return false
        end
        if (prev_point.point.x == path_point.point.x and path_point.point.y == next_point.point.y) or
            (prev_point.point.y == path_point.point.y and path_point.point.x == next_point.point.x)
          return true
        end
      end
    elsif path_points.size == 6
      path_points.each do |path_point|
        prev_point = path_point.prev
        unless (prev_point.curved_on_both_ends? and path_point.curved_at_right_end_only?) or
            (prev_point.curved_at_right_end_only? and path_point.curved_at_left_end_only?) or
            (prev_point.curved_at_left_end_only? and path_point.curved_on_both_ends?)
          return false
        end
      end
      return true
    elsif path_points.size == 8
      path_points.each do |path_point|
        prev_point = path_point.prev
        next_point = path_point.next
        unless ((prev_point.curved_at_right_end_only? and path_point.curved_at_left_end_only? and next_point.curved_at_right_end_only?) or
            (prev_point.curved_at_left_end_only? and path_point.curved_at_right_end_only? and next_point.curved_at_left_end_only?)) and
            prev_point.perpendicular? path_point and path_point.perpendicular? next_point
          return false
        end
      end
      return true
    end
    return false
  end
end