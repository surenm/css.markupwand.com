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
    @dom = []
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
  
  def regroup_vertically(dom, width, height)
    return dom
  end
  
  def regroup_horizontally(dom, width, height)
    pp "Regrouping horizontally"
    new_dom = []
    begin
      group = []
      dom_element = dom.first
      
      new_dummy_element = dom_element.clone
      new_dummy_element.right = new_dummy_element.left + width
            
      dom.each do |dom_element|
        if new_dummy_element.encloses? dom_element
          group.push dom_element
        end
      end
      group.each do |item|
        dom.delete item
      end
      new_dom.push group
    end while not dom.empty?
    
    return new_dom
  end
  
  def organize(dom_map, width, height)
    pp "Beginning to organize"
    # Just organize by height alone
    @children.each do |child_index|
      @dom.push dom_map.fetch child_index
    end

    @dom.sort!
    order = :horizontal
    new_dom = @dom
    begin
      @dom = new_dom
      if order == :vertical
        new_dom = regroup_vertically @dom, width, height
        order = :horizontal
      elsif order == :horizontal 
        new_dom = regroup_horizontally @dom, width, height
        order = :vertical
      end
    end while false
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
        css[:width] = 1024
        width = 1024
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