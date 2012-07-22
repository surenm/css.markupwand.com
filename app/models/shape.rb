class Shape
  SUPPORTED_SHAPES = [Shape::Box, Shape::Circle]
  def self.get_css_shape(path)
    SUPPORTED_SHAPES.each do |supported_shape|
      return supported_shape if supported_shape.my_type? path
    end
    return nil
  end
end