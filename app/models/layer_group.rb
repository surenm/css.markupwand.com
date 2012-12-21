class LayerGroup
  attr_accessor :layers
  
  def initialize(layers)
    self.layers = layers
  end

  def attribute_data
    layer_ids = self.layers.collect {|layer| layer.uid}
    
    attribute_data = { 
      :layers => layer_ids    
    }
  end

  def bounds
    bounding_boxes = layers.collect {|layer| layer.bounds}
    BoundingBox.get_super_bounds bounding_boxes
  end

  def to_s
    "#{Utils::get_group_key_from_layers self.layers}"
  end
end