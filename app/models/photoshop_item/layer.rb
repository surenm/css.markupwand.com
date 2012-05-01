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
    "layer : #{self.name}"
  end
  
  # TODO: This is a hard limit encloses function. 
  # This actually has to be something like if the areas intersect for more than 50% or so 
  # then the bigger one encloses the smaller one.
  def encloses?(other_layer)
    return (self.top <= other_layer.top and self.left <= other_layer.left and self.bottom >= other_layer.bottom and self.right >= other_layer.right)
  end
  
  def render_to_html()
    #puts "Generating html for #{self.inspect}"
    html = ""
    
    if self.layer[:layerKind] == "LayerKind.TEXT"
      element = :div
      inner_html = self.layer[:textKey][:value][:textKey][:value]
      css = Converter::parse_text self.layer
      style_string = Converter::to_style_string css
    elsif self.layer[:layerKind] == "LayerKind.SMARTOBJECT"
      element = :img
      inner_html = ''
      image_path = Converter::get_image_path self.layer
      style_string = ''
      #puts "smart object layer"
    elsif self.layer[:layerKind] == "LayerKind.SOLIDFILL"
      css = Converter::parse_box self.layer
      width = self.width
      height = self.height
      element = :div
      if root 
        element = :body
        css.delete :width
        css.delete :height
        css.delete :'min-height'
        css[:margin] = "0 auto"
        css[:width] = 1024
        width = 1024
      end
      style_string = Converter::to_style_string css  
    end
  
    attributes = {}
    attributes[:style] = style_string
    
    
    if element == :img
      html = "<img src='#{image_path}'>"
    else
      html = content_tag element, inner_html, {:style => style_string}, false
    end
    
    return html
  end
end