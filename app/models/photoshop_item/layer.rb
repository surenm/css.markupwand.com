class PhotoshopItem::Layer
  include ActionView::Helpers::TagHelper

  attr_accessor :bounds, :name, :layer, :kind, :uid


  LAYER_TEXT        = "LayerKind.TEXT"
  LAYER_SMARTOBJECT = "LayerKind.SMARTOBJECT"
  LAYER_SOLIDFILL   = "LayerKind.SOLIDFILL"
  LAYER_NORMAL      = "LayerKind.NORMAL"
  
  def initialize(layer)    
    bound_json = layer[:bounds]
    @name   = layer[:name][:value]
    @kind   = layer[:layerKind]
    @uid    = layer[:layerID][:value]

    self.layer  = layer

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

  def is_not_root_node
    @is_root = false
  end

  def <=> (other_layer)
    self.bounds <=> other_layer.bounds
  end

  def ==(other_layer)
    return false if other_layer == nil
    return (
    self.bounds == other_layer.bounds and
    self.name == other_layer.name and
    self.children == other_layer.children
    )
  end
=begin
  def inspect
    "#{self.name}: #{self.bounds} \n"
  end
=end
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
    elsif layer_kind == LAYER_SMARTOBJECT
      :img
    elsif layer_kind  == LAYER_TEXT or layer_kind == LAYER_SOLIDFILL or layer_kind == LAYER_NORMAL
      :div
    else
      Log.info "New layer found #{layer_kind} for layer #{self.name}"
      :div
    end
  end

  def get_css(css = {}, is_root = false)
    if layer_kind == LAYER_TEXT
      css.update Converter::parse_text self.layer
    elsif layer_kind == LAYER_SMARTOBJECT
      # don't do anything
    elsif layer_kind == LAYER_SOLIDFILL
      css.update Converter::parse_box self.layer
      if is_root
        css.delete :width
        css.delete :height
        css.delete :'min-height'
        css[:margin] = "0 auto"
        css[:width] = '960px'
      end
    end
    
    css
  end

  def class_name(css = {}, is_root = false)
    css = get_css(css, is_root)
    PhotoshopItem::StylesHash.add_and_get_class(Converter::to_style_string(css))
  end

  def text
    if layer_kind == LAYER_TEXT
      self.layer[:textKey][:value][:textKey][:value]
    else
      ''
    end
  end

  def to_html(args = {})
    #puts "Generating html for #{self.inspect}"
    css = args.fetch :css, {}
    css_class = class_name css, @is_root
    
    inner_html = args.fetch :inner_html, ''
    if inner_html.empty? and layer_kind == LAYER_TEXT
      inner_html = text
    end
    
    attributes = Hash.new
    attributes[:class] = css_class

    if tag == :img
      html = "<img src='#{image_path}'/>"
    else
      html = content_tag tag, inner_html, attributes, false
    end
    
    return html
  end

  def to_s
    "#{self.name} -- #{self.bounds}"
  end
end
