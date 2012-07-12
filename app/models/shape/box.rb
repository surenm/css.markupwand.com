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
    if num_straight_segments == 2
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
    elsif num_straight_segments == 0 and num_segments%2 == 0
      curves = path_segments.collect { |segment| segment.curve_type }
      non_boxy_curves = curves.select {|curve| curve == Shape::PathSegment::CURVE_TYPE_BOTH}
      x_curves = curves.select {|curve| curve == Shape::PathSegment::CURVE_TYPE_X}
      y_curves = curves.select {|curve| curve == Shape::PathSegment::CURVE_TYPE_Y}
      curve_balance_index = x_curves - y_curves
      if non_boxy_curves.size == 0 and curve_balance_index == 0
        return true
      end
    end
    return false
  end
end