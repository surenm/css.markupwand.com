class PhotoshopItem::StylesHash
  
  attr_accessor :styles, :index
  
  def initialize(font_map)
    @css_classes = Hash.new
    @index  = 0
  end
  
  def debug
    ENV.has_key? 'DEBUG' and ENV['DEBUG'].to_i > 0
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
  
  def write_css_file(folder_path)
    css_path = folder_path.join("assets", "css")
    FileUtils.mkdir_p css_path
    
    css_file = css_path.join "style.css"
    Log.info "Writing css file #{css_file}"
    
    File.open(css_file, 'w') {|f| f.write(generate_css_data) }
  end
  
  def generate_css_data
   
    css_data = ''
    
    # Debugging div positioning
    if debug
      css_data += <<DIV_BLOCK
  div {
    border: 1px #f00 dotted;
  }
DIV_BLOCK
    end
      
    @css_classes.each do |style, class_name|
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
    spanx = ((24*width)/960.0).round.to_i
    return "span#{spanx}"
  end
  
end