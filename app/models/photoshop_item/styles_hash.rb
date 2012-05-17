class PhotoshopItem::StylesHash
  attr_accessor :css_classes
  
  def initialize
    Log.fatal "Creating an instance"
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
  
  def self.debug
    ENV.has_key? 'DEBUG' and ENV['DEBUG'].to_i > 0
  end

  def self.instance
    return @@instance
  end
  
  def self.add_and_get_class(string)
    @@instance.add_and_get_class(string)
  end
  
  def self.write_css_file(folder_path)
    css_path = folder_path.join("assets", "css")
    FileUtils.mkdir_p css_path
    
    css_file = css_path.join "style.css"
    Log.info "Writing css file #{css_file}"
    
    File.open(css_file, 'w') {|f| f.write(generate_css_data) }
  end
  
  def self.generate_css_data
    css_classes = @@instance.css_classes
    css_data    = ''
    
    # Debugging div positioning
    if self.debug
      css_data += <<DIV_BLOCK
  div {
    border: 1px Gray dotted;
  }
DIV_BLOCK
    end
      
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
  
  def self.get_bootstrap_width_class(width)
    spanx = ((12*width)/960).round.to_i
    return "span#{spanx}"
  end
  
end
