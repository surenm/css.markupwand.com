class Shape::Box
  def initialize

  end

  def self.is_box?(path_segments)
    num_segments = path_segments.size
    straight_segments = path_segments.select { |segment| segment.type == Shape::PathSegment::TYPE_STRAIGHT }
    num_straight_segments = straight_segments.size

    # There has to be either 2 or 4 lines in a rectangle, whether rounded or not
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
    end
    return false
  end


end