class Shape::Box
  def initialize

  end

  def self.is_box?(path_segments)
    num_segments = path_segments.size
    straight_segments = path_segments.select { |segment| segment.type == Shape::PathSegment::TYPE_STRAIGHT }
    num_straight_segments = straight_segments.size

    # There has to be either 2 or 4 lines in a sharp rectangle
    # Not considering cases where the designer drew a line of a certain length,
    # changed mind and drew another segment to extend the line, etc.
    # And each of those straight lines need to have a parallel pair
    if num_straight_segments == 2 and path_segments.size == num_straight_segments
      return true if straight_segments[0].parallel? straight_segments[1]
    elsif num_straight_segments == 4
      if (straight_segments[0].parallel? straight_segments[1] and straight_segments[2].parallel? straight_segments[3]) or
          (straight_segments[0].parallel? straight_segments[2] and straight_segments[1].parallel? straight_segments[3]) or
          (straight_segments[0].parallel? straight_segments[3] and straight_segments[1].parallel? straight_segments[2])
        return true
      end
    # In a simple rounded rectangle, lines would turn slightly in just one dimension at a time
    # No segment should have turn in more than one dimension(x or y only; not both)
    # And there can't be an odd number of segments for a box
    elsif num_straight_segments == 0 and num_segments.even?
      curve_data = {
          :x => {
            :count => 0,
            :concave_count => 0,
            :convex_count => 0
          },
          :y => {
              :count => 0,
              :concave_count => 0,
              :convex_count => 0
          }
      }

      path_segments.each do |segment|
        if segment.curved_x?
          curve_data[:x][:count] += 1
          if segment.convex?
            curve_data[:x][:convex_count] += 1
          elsif segment.concave?
            curve_data[:x][:concave_count] += 1
          end
        elsif segment.curved_y?
          curve_data[:y][:count] += 1
          if segment.convex?
            curve_data[:y][:convex_count] += 1
          elsif segment.concave?
            curve_data[:y][:concave_count] += 1
          end
        end
      end

      curves_balanced = true
      if curve_data[:x][:count].odd? or curve_data[:y][:count].odd?
        curves_balanced = false
      end
      if (curve_data[:x][:convex_count] != curve_data[:x][:concave_count] or
          curve_data[:y][:convex_count] != curve_data[:y][:concave_count])
         curves_balanced = false
      end

      # Ideally should check if none of the segments are not suitable for a standard box.
      # Reserving for later, and looking at whether curves are balanced alone.
      # The concave/convex logic isn't perfectly right. Won't work for cases where
      # one segment would form the entire curved side(with a large border radius) of a button
      if curves_balanced
        return true
      end
    end
    return false
  end
end