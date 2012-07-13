class Shape::Point
  attr_accessor :x, :y
  def initialize(x,y)
    self.x = x
    self.y = y
  end

  def ==(other)
    self.x == other.x and self.y == other.y
  end

  def inspect
    "(#{x}, #{y})"
  end
end