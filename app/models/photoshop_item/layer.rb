class PhotoshopItem::Layer
  include ActionView::Helpers::TagHelper
  
  attr_reader :top, :bottom, :left, :right, :name, :layer
  attr_accessor :children
  
  def initialize(layer)    
    @bounds = layer[:bounds]
    @name   = layer[:name][:value]
    @layer  = layer

    value   = @bounds[:value]
    @top    = value[:top][:value]
    @bottom = value[:bottom][:value]
    @left   = value[:left][:value]
    @right  = value[:right][:value]    

    @children = []
  end
  
  def <=>(other_layer)
    if self.top < other_layer.top
      return -1
    else
      return self.left <=> other_layer.left
    end
  end
  
  def inspect
    s = <<LAYER
    layer : #{self.name}
    start : #{self.top}, #{self.left}
    width : #{self.width}
    height: #{self.height}
    children: #{self.children}
LAYER
    s
  end
  
  def encloses?(other_layer)
    return (self.top <= other_layer.top and self.left <= other_layer.left and self.bottom >= other_layer.bottom and self.right >= other_layer.right)
  end
  
  def height
    @bottom - @top
  end
  
  def width
    @right - @left
  end
  
  def render_to_html(dom_map, root = false)
    puts "Generating html for #{self.name}"
    html = ""
    if self.layer[:layerKind] == "LayerKind.TEXT"
      #puts "Text layer"
    elsif self.layer[:layerKind] == "LayerKind.SMARTOBJECT"
      #puts "smart object layer"
    elsif self.layer[:layerKind] == "LayerKind.SOLIDFILL"
      css = Converter::parse_box self.layer
      element = :div
      if root 
        element = :body
        css.delete :width
        css.delete :height
        css.delete :'min-height'
      end
    
    
      style_string = Converter::to_style_string css
      html = content_tag element, nil, :style => style_string
    end
    
    @children.each do |child_index|
      child = dom_map.fetch child_index
      child.render_to_html dom_map
    end
    
    return html
  end
end
