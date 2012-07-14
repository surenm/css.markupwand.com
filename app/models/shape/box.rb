class Shape::Box
  def initialize

  end

  def self.curves_balanced?(path_segments)
    # Ideally should check if none of the segments are not suitable for a standard box.
    # Reserving for later, and looking at whether curves are balanced alone.
    # The concave/convex logic isn't perfectly right. Won't work for cases where
    # one segment would form the entire curved side(with a large border radius) of a button
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
    return curves_balanced
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
    elsif num_straight_segments == 4
      if (straight_segments[0].parallel? straight_segments[1] and straight_segments[2].parallel? straight_segments[3]) or
          (straight_segments[0].parallel? straight_segments[2] and straight_segments[1].parallel? straight_segments[3]) or
          (straight_segments[0].parallel? straight_segments[3] and straight_segments[1].parallel? straight_segments[2])
        return true
      end
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