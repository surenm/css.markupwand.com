class PhotoshopItem::LayerBounds
  attr_reader :top, :bottom, :left, :right, :name
  
  def initialize(layer)    
    @bounds = layer[:bounds]
    @name = layer[:name][:value]

    value   = @bounds[:value]
    @top    = value[:top][:value]
    @bottom = value[:bottom][:value]
    @left   = value[:left][:value]
    @right  = value[:right][:value]    
  end
  
  def <=>(other_layer_bounds)
    if self.top < other_layer_bounds.top
      return -1
    else
      return self.left <=> other_layer_bounds.left
    end
  end
  
  def inspect
    s = <<LAYERBOUNDS
    Layer : #{@parent}
    Start : #{@top}, #{@left}
    Width : #{self.width}
    Height: #{self.height}
LAYERBOUNDS
    
    s
  end
  end
  
  def height
    @bottom - @top
  end
  
  def width
    @right - @left
  end
end
