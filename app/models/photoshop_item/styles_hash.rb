class PhotoshopItem::StylesHash
  attr_accessor :css_classes
  
  def initialize
    @css_classes = Hash.new
    @index  = 0
  end
  
  def add_and_get_class(css)
    if css.empty?
      return nil
    end
    
    if @css_classes.has_key? css
      return @css_classes[css]
    else
      @index = @index + 1
      class_name = 'class' + (@index).to_s
      @css_classes[css] = class_name
      return class_name
    end
  end
  
  @@instance = PhotoshopItem::StylesHash.new
  
  def self.instance
    return @@instance
  end
  
  def self.add_and_get_class(string)
    @@instance.add_and_get_class(string)
  end
    
  def self.generate_css_data
    css_classes = @@instance.css_classes
    css_data    = ''
    
    css_classes.each do |style, class_name|
      style_formatted = style.gsub(";",";\n")
      class_block = <<CLASS_BLOCK
.#{class_name} {
  #{style_formatted}
}

CLASS_BLOCK
      css_data = css_data + class_block
    end
    
    return css_data
  end
  
  def generate_body_style(root_grid)
    css = {}
    root_grid.body_style_layers.each do |layer|
      css.update 
    end
  end

  def self.get_bootstrap_width_class(width)    
    spanx = (width/40.0).round.to_i
    return "span#{spanx}"
  end
  
end
