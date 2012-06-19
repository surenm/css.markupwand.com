class DomParser
  def initialize(grid_id)
    @grid = Grid.find grid_id
    @tag = @grid.tag.to_sym
  end
  
  def reparse
    case @tag
    when :a
      self.parse_anchor_grid
    when :div
      self.parse_normal_grid
    else
      Log.fatal "Dunno how to parse this tag yet" 
    end
  end
  
  def get_text_layers()
    @grid.layers.select do |layer|
      layer.kind == Layer::LAYER_TEXT
    end
  end
  
  def get_style_layers()
    @grid.layers.select do |layer|
      layer.kind != Layer::LAYER_TEXT
    end
  end
  
  def parse_anchor_tag
    text_layers  = self.get_text_layers 
    style_layers = self.get_style_layers
    
    Log.error "Text layers are #{text_layers}"
    Log.error "Style layers are #{style_layers}"
    
    if text_layers.size == 1
      Log.error "Setting renderlayer to #{text_layers.first}"
      @grid.render_layer = text_layers.first.id
      @grid.children.delete_all
      @grid.save!
    end
  end
  
  def parse_normal_grid
    # This grid has :div as the tag
  end
end