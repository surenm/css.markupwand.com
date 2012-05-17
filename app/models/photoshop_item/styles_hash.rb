class PhotoshopItem::StylesHash
  def initialize
    @styles = Hash.new
    @index  = 0
  end
  
  def styles
    @styles
  end
  
  def self.debug
    ENV.has_key? 'DEBUG' and ENV['DEBUG'].to_i > 0
  end
  
  @@instance = PhotoshopItem::StylesHash.new
  
  def self.instance
    return @@instance
  end
  
  def add_and_get_class(css)
    if css.empty?
      return nil
    end
    
    if @styles.has_key? css
      return @styles[css]
    else
      @index = @index + 1
      class_name = 'class' + (@index).to_s
      @styles[css] = class_name
      return class_name
    end
  end
  
  def self.get_styles_hash
    PhotoshopItem::StylesHash.instance.styles
  end
  
  def self.add_and_get_class(string)
    PhotoshopItem::StylesHash.instance.add_and_get_class(string)
  end
  
  def self.generate_css_file
    classes  = PhotoshopItem::StylesHash.get_styles_hash
    css_data = ''
    
    # Debugging div positioning
    if self.debug
      css_data += <<DIV_BLOCK
  div {
    border: 1px Gray dotted;
  }
DIV_BLOCK
    end
      
    classes.each do |style, class_name|
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
  
  def self.get_bootstrap_width_class(width)
    spanx = ((12*width)/960).round.to_i + 1
    return "span#{spanx}"
  end
  
end