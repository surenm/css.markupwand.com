class Shape::PathSegment
  attr_reader :point, :left_dir, :right_dir, :type, :curve_dir, :curve_type

  TYPE_STRAIGHT = :straight
  TYPE_CURVED = :curved

  CURVE_DIR_X = :curve_dir_x
  CURVE_DIR_Y = :curve_dir_y
  CURVE_DIR_BOTH = :curve_dir_xy
  CURVE_DIR_NONE = :curve_dir_none

  CURVE_TYPE_CONCAVE = :curve_type_concave
  CURVE_TYPE_CONVEX = :curve_type_convex
  CURVE_TYPE_BOTH = :curve_type_both
  CURVE_TYPE_NONE = :curve_type_none

  private
  def set_type
    if point == left_dir and left_dir == right_dir
      @type = TYPE_STRAIGHT
    else
      @type = TYPE_CURVED
    end
  end

  def set_curve
    if self.type.nil?
      set_type
    end

    if self.type == TYPE_STRAIGHT
      @curve_type = CURVE_NONE
    elsif self.point.x == self.left_dir.x and self.left_dir.x == self.right_dir.x
        @curve_type = CURVE_TYPE_Y
    elsif self.point.y == self.left_dir.y and self.left_dir.y == self.right_dir.y
        @curve_type = CURVE_TYPE_X
    else
        @curve_type = CURVE_TYPE_BOTH
    end

    if self.type == TYPE_STRAIGHT

    end
  end

  public
  def initialize(coordinates)
    if coordinates.size < 6
      raise "There are less than 6 coordinates in the path segment item. Old version of json?"
    end
    @point = Shape::Point.new(coordinates[0], coordinates[1])
    @left_dir = Shape::Point.new(coordinates[2], coordinates[3])
    @right_dir = Shape::Point.new(coordinates[4], coordinates[5])
    set_type
    set_curve
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