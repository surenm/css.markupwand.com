class TagHandler
  def initialize(grid_id)
    @grid = Grid.find grid_id
    Log.info @grid
    @tag = @grid.override_tag
  end
  
  def repair
    return if @tag.nil?
    if @tag == "a"
      self.handle_anchor_tag
    end
  end
  
  def TagHandler.get_text_layers(grid)
    grid.layers.select do |layer|
      layer.kind == Layer::LAYER_TEXT
    end
  end
  
  def TagHandler.get_style_layers(grid)
    grid.layers.select do |layer|
      layer.kind != Layer::LAYER_TEXT
    end
  end
  
  def handle_anchor_tag
    text_layers  = TagHandler.get_text_layers @grid
    style_layers = TagHandler.get_style_layers @grid
    
    Log.info text_layers
    Log.info style_layers
  end
end