class PhotoshopItem::Layer
  include ActionView::Helpers::TagHelper
  
  attr_reader :top, :bottom, :left, :right, :name, :layer
  attr_accessor :children
  
  LAYER_TEXT = "LayerKind.TEXT"
  LAYER_SMARTOBJECT = "LayerKind.SMARTOBJECT"
  LAYER_SOLIDFILL   = "LayerKind.SOLIDFILL"
  
  
  def initialize(layer)    
    @bounds = layer[:bounds]
    @name   = layer[:name][:value]
    @layer  = layer

    value    = @bounds[:value]
    @top     = value[:top][:value]
    @bottom  = value[:bottom][:value]
    @left    = value[:left][:value]
    @right   = value[:right][:value]  
    @is_root = false

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
  
  def organize(dom_map)
    # Just organize by height alone
    @children.sort! { |a, b| dom_map[a].top <=> dom_map[b].top }
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
    if is_root
      :body
    elsif layer_kind  == LAYER_TEXT or layer_kind == LAYER_SOLIDFILL
      :div
    elsif layer_kind == LAYER_SMARTOBJECT
      :img
    end
  end
  
  def style
    if layer_kind == LAYER_TEXT
      Converter::to_style_string (Converter::parse_text self.layer)
    elsif layer_kind == LAYER_SMARTOBJECT
      ''
    elsif layer_kind == LAYER_SOLIDFILL
      css = Converter::parse_box self.layer
      if is_root
        css.delete :width
        css.delete :height
        css.delete :'min-height'
        css[:margin] = "0 auto"
        css[:width] = 960
      end
      Converter::to_style_string css
    end
  end
  
  def inner_html
    if layer_kind == LAYER_TEXT
      self.layer[:textKey][:value][:textKey][:value]
    else
      ''
    end
  end
  
  def render_to_html(dom_map)
    html = ""
        
    if not @children.empty?
      organize dom_map
      children_dom = []
      @children.each do |child_index|
        child = dom_map.fetch child_index
        children_dom.push(child.render_to_html dom_map)
      end
      inner_html = children_dom.join(" ")
    end
    
    if element == :img
      html = "<img src='#{image_path}'>"
    else
      html = content_tag tag, inner_html, {:style => style}, false
    end
    
    return html
  end
end