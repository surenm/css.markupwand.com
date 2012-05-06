class PhotoshopItem::Layer
  include ActionView::Helpers::TagHelper
  
  attr_accessor :bounds, :name, :layer, :kind
  
  
  LAYER_TEXT        = "LayerKind.TEXT"
  LAYER_SMARTOBJECT = "LayerKind.SMARTOBJECT"
  LAYER_SOLIDFILL   = "LayerKind.SOLIDFILL"
  
  def initialize(layer)    
    bound_json = layer[:bounds]
    @name   = layer[:name][:value]
    @kind   = layer[:layerKind]
    @layer  = layer

    value    = bound_json[:value]
    top     = value[:top][:value]
    bottom  = value[:bottom][:value]
    left    = value[:left][:value]
    right   = value[:right][:value]  
    @is_root = false
    
    @bounds = BoundingBox.new(top, left, bottom, right)
    
  end
  
  # Sets that it is a root
  def is_a_root_node
    @is_root = true
  end
  
  def <=> (other_layer)
    self.bounds <=> other_layer.bounds
  end

  def ==(other_layer)
    return (
      self.bounds.same_as? other_layer.bounds and
      self.name == other_layer.name and 
      self.children == other_layer.children
    )
  end
  
  def inspect
    "#{self.name}: (#{self.top}, #{self.left}) - #{self.width} wide, #{self.height} high \n"
  end
  
  # TODO: This is a hard limit encloses function. 
  # This actually has to be something like if the areas intersect for more than 50% or so 
  # then the bigger one encloses the smaller one.
  def encloses?(other_layer)
    return self.bounds.encloses? other_layer.bounds
  end
  
  def intersect?(other)
    return self.bounds.intersect? other.bounds
  end
  
  def image_path
    if layer_kind == LAYER_SMARTOBJECT
      Converter::get_image_path self.layer
    else
      nil
    end
  end
  
  def layer_kind
    self.layer[:layerKind]
  end
  
  def tag
    if @is_root
      :body
    elsif layer_kind  == LAYER_TEXT or layer_kind == LAYER_SOLIDFILL
      :div
    elsif layer_kind == LAYER_SMARTOBJECT
      :img
    end
  end
  
  def class_name(css)
    if layer_kind == LAYER_TEXT
      css.update Converter::parse_text self.layer
    elsif layer_kind == LAYER_SMARTOBJECT
      css.update {}
    elsif layer_kind == LAYER_SOLIDFILL
      css.update Converter::parse_box self.layer
      if @is_root
        css.delete :width
        css.delete :height
        css.delete :'min-height'
        css[:margin] = "0 auto"
        css[:width] = 960
      end
    end
    
    PhotoshopItem::StylesHash.add_and_get_class(Converter::to_style_string(css))
  end
  
  def text
    if layer_kind == LAYER_TEXT
      self.layer[:textKey][:value][:textKey][:value]
    else
      ''
    end
  end
  
  def render_to_html(args = nil)
    #puts "Generating html for #{self.inspect}"
    override_css = {}
    if not args.nil?
      if not args[:css].nil?
        override_css = args[:css]
      end
    end
    
    inner_html = text  
    if tag == :img
      html = "<img src='#{image_path}'/>"
    else
      html = content_tag tag, inner_html, {:class => class_name(override_css)}, false
    end    
    return html
  end
end