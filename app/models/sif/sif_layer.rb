class Sif::SifLayer
 
  # TODO Mongo remove
  def kind
  	Layer::LAYER_NORMAL
  end

  # Whether the current layer should be rendering a image or not.
  # This should be figured out whether it is background layer or not
  def renderImage
  	false
  end

end