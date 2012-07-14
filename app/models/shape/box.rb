class Shape::Box
  def initialize

  end

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

  def self.is_box?(path_segments)
    num_segments = path_segments.size
    straight_segments = path_segments.select { |segment| segment.straight? }
    num_straight_segments = straight_segments.size
    segments_curved_at_one_end = path_segments.select { |segment| segment.curved_at_one_end?}
    num_curved_at_one_end = segments_curved_at_one_end.size
    num_non_boxy_segments = num_segments - (num_straight_segments + num_curved_at_one_end)

    if num_non_boxy_segments == num_segments
      return false
    # There has to be either 2 or 4 lines in a sharp rectangle
    # Not considering cases where the designer drew a line of a certain length,
    # changed mind and drew another segment to extend the line, etc.
    # And each of those straight lines need to have a parallel pair
    elsif num_straight_segments == 2 and path_segments.size == num_straight_segments
      return true if straight_segments[0].parallel? straight_segments[1]
    elsif num_straight_segments == 4 and curves_balanced? path_segments and
      ((straight_segments[0].parallel? straight_segments[1] and straight_segments[2].parallel? straight_segments[3]) or
        (straight_segments[0].parallel? straight_segments[2] and straight_segments[1].parallel? straight_segments[3]) or
        (straight_segments[0].parallel? straight_segments[3] and straight_segments[1].parallel? straight_segments[2]))
      return true
    # In a simple rounded rectangle, lines would turn slightly in just one dimension at a time
    # No segment should have turn in more than one dimension(x or y only; not both)
    # And there can't be an odd number of segments for a box
    elsif num_non_boxy_segments <= 4 and num_non_boxy_segments.even? and num_segments.even? and num_segments <= 8
      if curves_balanced? path_segments
        return true
      end
    end
    return false
  end
end