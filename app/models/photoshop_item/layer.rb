class PhotoshopItem::Layer
  include ActionView::Helpers::TagHelper
  
  attr_accessor :top, :bottom, :left, :right, :name, :layer, :kind
  attr_reader :width, :height
  
  def initialize(layer)    
    @bounds = layer[:bounds]
    @name   = layer[:name][:value]
    @kind   = layer[:layerKind]
    @layer  = layer

    value   = @bounds[:value]
    @top    = value[:top][:value]
    @bottom = value[:bottom][:value]
    @left   = value[:left][:value]
    @right  = value[:right][:value]    
    
    @width  = @right - @left
    @height = @bottom - @top
  end
  
  def <=>(other_layer)
    if self.top == other_layer.top
      return self.left <=> other_layer.left
    else
      return self.top <=> other_layer.top
    end
  end
  
  def ==(other_layer)
    return (
      self.top == other_layer.top and
      self.left == other_layer.left and 
      self.bottom == other_layer.bottom and 
      self.right == other_layer.right and
      self.name == other_layer.name and 
      self.children == other_layer.children
    )
  end
  
  def inspect
    "#{self.name}: (#{self.top}, #{self.left}) - #{self.width} wide, #{self.height} high"
  end
  
  # TODO: This is a hard limit encloses function. 
  # This actually has to be something like if the areas intersect for more than 50% or so 
  # then the bigger one encloses the smaller one.
  def encloses?(other_layer)
    return (self.top <= other_layer.top and self.left <= other_layer.left and self.bottom >= other_layer.bottom and self.right >= other_layer.right)
  end
  
  def intersect?(other)
    return (self.left < other.right and self.right > other.left and self.top < other.bottom and self.bottom > other.top)
  end
  
  def render_to_html(args = nil)
    #puts "Generating html for #{self.inspect}"
    css = {}
    if not args.nil?
      if not args[:css].nil?
        css = args[:css]
      end
    end
    
    html = ""
    if self.kind == "LayerKind.TEXT"
      tag = :div
      css.merge! Converter::parse_text self.layer
      inner_html = self.layer[:textKey][:value][:textKey][:value]
      style_string = Converter::to_style_string css
    elsif self.kind == "LayerKind.SMARTOBJECT"
      tag = :img
      image_path = Converter::get_image_path self.layer
    elsif self.kind == "LayerKind.SOLIDFILL"
      tag = :div
      css.merge! Converter::parse_box self.layer
      width = self.width
      height = self.height
    end

    style_string = Converter::to_style_string css
    attributes = {}
    attributes[:style] = style_string
    
    if tag == :img
      html = "<img src='#{image_path}'/>"
    else
      html = content_tag tag, inner_html, {:style => style_string}, false
    end    
    return html
  end
end