class PhotoshopItem::LayerBounds
  def initialize(bounds_obj)
    value = bounds_obj[:value]

    @top    = value[:top][:value]
    @bottom = value[:bottom][:value]
    @left   = value[:left][:value]
    @right  = value[:left][:value]    
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
  
  def get_height
    @bottom - @top
  end
  
  def get_width
    @right - @left
  end
end
