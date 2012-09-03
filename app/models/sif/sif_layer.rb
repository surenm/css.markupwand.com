class Sif::SifLayer
  def self.create(layer_json, design)
    layer            = Layer.new
    layer.name       = layer_json[:name]
    layer.layer_type = layer_json[:layerType] 
    layer.kind       = layer_json[:layerType] # TODO: fix this
    layer.uid        = layer_json[:layerId]
    layer.zindex     = layer_json[:zindex]
    layer.design     = design

    raw_bounds 	= layer_json[:bounds]
    bounds 		= BoundingBox.new raw_bounds[:top],
      raw_bounds[:left], raw_bounds[:bottom], raw_bounds[:right]
    
    layer.initial_bounds = bounds
    design_bounds 		 = BoundingBox.new 0, 0, layer.design.height, layer.design.width
    
    layer_bounds 		 = bounds.inner_crop(design_bounds)

    if layer_bounds.nil?
      layer.invalid_layer = true
    else
      layer.invalid_layer = false
      layer.layer_bounds  = BoundingBox.pickle layer_bounds
    end

    layer
  end
end