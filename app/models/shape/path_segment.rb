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
  CURVE_TYPE_COMPLEX = :curve_type_complex
  CURVE_TYPE_NONE = :curve_type_none

  private
  def set_type
    if point == left_dir and left_dir == right_dir
      @type = TYPE_STRAIGHT
    else
      @type = TYPE_CURVED
    end
  end

  def get_curve_type(anchor, dir1, dir2)
    # FIXME: This logic is not right to check if something is concave or convex.
    # But letting it be there for the time being
    if anchor <= dir1 and anchor <= dir2
      @curve_type = CURVE_TYPE_CONCAVE
    elsif anchor >= dir1 and anchor >= dir2
      @curve_type = CURVE_TYPE_CONVEX
    else
      @curve_type = CURVE_TYPE_COMPLEX
    end
  end

  def set_curve
    if self.type.nil?
      set_type
    end

    if self.type == TYPE_STRAIGHT
      @curve_dir = CURVE_DIR_NONE
      @curve_type = CURVE_TYPE_NONE
    elsif self.point.x == self.left_dir.x and self.left_dir.x == self.right_dir.x
      @curve_dir = CURVE_DIR_Y
      @curve_type = get_curve_type(self.point.y, self.left_dir.y, self.right_dir.y)
    elsif self.point.y == self.left_dir.y and self.left_dir.y == self.right_dir.y
      @curve_dir = CURVE_DIR_X
      @curve_type = get_curve_type(self.point.x, self.left_dir.x, self.right_dir.x)
    else
      @curve_dir = CURVE_DIR_BOTH
      # FIXME: Curve type may not be complex here.
      # But since we don't care about the type, setting it to complex for simplicity of code.
      # This would anyways be handled as image
      @curve_type = CURVE_TYPE_COMPLEX
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

  def curved?
    !(self.curve_dir == CURVE_DIR_NONE and self.curve_type == CURVE_TYPE_NONE)
  end

  def curved_x?
    self.curve_dir == CURVE_DIR_X
  end

  def curved_y?
    self.curve_dir == CURVE_DIR_Y
  end

  def curved_both_axes?
    self.curve_dir == CURVE_DIR_BOTH
  end

  def concave?
    self.curve_type == CURVE_TYPE_CONCAVE
  end

  def convex?
    self.curve_type == CURVE_TYPE_CONVEX
  end

  def complex?
    self.curve_type == CURVE_TYPE_COMPLEX
  end

  def inspect
    "Point: #{self.point} | Left Dir: #{self.left_dir} | Right Dir: #{self.right_dir}"
  end
end