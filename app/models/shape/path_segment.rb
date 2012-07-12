class Shape::PathSegment
  attr_reader :point, :left_dir, :right_dir, :type

  TYPE_STRAIGHT = :straight
  TYPE_CURVED = :curved

  private
  def typify
    if point == left_dir and left_dir == right_dir
      return TYPE_STRAIGHT
    else
      return TYPE_CURVED
    end
  end

  public
  def initialize(coordinates)
    if coordinates.size < 6
      raise "There are less than 6 coordinates in the path segment item. Old version of json?"
    end
    @point = Point.new(coordinates[0], coordinates[1])
    @left_dir = Point.new(coordinates[2], coordinates[3])
    @right_dir = Point.new(coordinates[4], coordinates[5])
    @type = typify
  end

  # Returns true only for straight and parallel lines. Doesn't handle curved parallel lines.
  def parallel?(other)
    self.type == TYPE_STRAIGHT and other.type == TYPE_STRAIGHT and (self.point.x == other.point.x or self.point.y == other.point.y)
  end

  def select_parallel_items(path_item_list)
    path_item_list.select do |other_item|
      self.parallel? other_item
    end
  end
end