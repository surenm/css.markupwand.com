class PhotoshopItem::LayerBounds
  def initialize(bounds_obj)
    value = bounds_obj[:value]

    @top    = value[:top][:value]
    @bottom = value[:bottom][:value]
    @left   = value[:left][:value]
    @right  = value[:left][:value]    
  end
  
  def get_height
    @bottom - @top
  end
  
  def get_width
    @right - @left
  end
end
