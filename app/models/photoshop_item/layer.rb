class PhotoshopItem::Layer
  include ActionView::Helpers::TagHelper
  
  attr_accessor :top, :bottom, :left, :right, :name, :layer, :children

  
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
  
  # TODO: This is a hard limit encloses function. 
  # This actually has to be something like if the areas intersect for more than 50% or so 
  # then the bigger one encloses the smaller one.
  def encloses?(other_layer)
    return (self.top <= other_layer.top and self.left <= other_layer.left and self.bottom >= other_layer.bottom and self.right >= other_layer.right)
  end
  
  def height
    @bottom - @top
  end
  
  def width
    @right - @left
  end
  
  def area
    self.height * self.width
  end
  
  def grouping(order, children)
    pp "Sorting #{order} wise"
    group = Hash.new
    pp children
    children.each do |child|
            
      key = Constants.round_to_nearest_five child.top if order == :horizontal
      key = Constants.round_to_nearest_five child.left if order == :vertical

      group[key] = PhotoshopItem::LayerGroup.new if group[key].nil?
      group[key].add_layer child
    end
    pp group
    return group
  end
  
  def organize(dom_map, width, height)
    # Just organize by height alone
    children_layers = []
    @children.each do |child_index|
      children_layers.push dom_map.fetch child_index
    end
    
    children_group = children_layers
    new_children_group = children_group
    order = :horizontal
    begin
      children_group = new_children_group
      new_children_group = grouping order, children_group
  
      if order == :horizontal
        order == :vertical
      elsif order == :vertical
        order == :horizontal
      end
    end while children_group != new_children_group
    
      @children.sort! { |a, b| 
        dom_map[a].top <=> dom_map[b].top
    }
  end
  
  def render_to_html(dom_map, root = false)
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
        css[:width] = 960
        width = 960
      end
      style_string = Converter::to_style_string css  
    end
    
    if not @children.empty?
      organize dom_map, width, height
      children_dom = []
      @children.each do |child_index|
        child = dom_map.fetch child_index
        children_dom.push(child.render_to_html dom_map)
      end
      inner_html = children_dom.join(" ")
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