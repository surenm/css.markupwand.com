# Runs through nodejs.
# Format: ruby CssParser.rb <filename>
require 'rubygems'
require 'json'
require 'pp'

# Modify float to cut off to few significant digits
class Float
  def sigfig(digits)
    sprintf("%.#{digits - 1}e", self).to_f
  end
end

module CssParser

  def CssParser::set_assets_root(root)
    # Create assets folder
    assets_path = root.join "assets"
    FileUtils.mkdir_p assets_path
    
    ENV["ASSETS_DIR"] = assets_path.to_s
  end
  
  def CssParser::get_assets_root
    ENV["ASSETS_DIR"]
  end

  def CssParser::parse_color(color_object)
    red   = (Integer(color_object[:value][:red][:value])).to_s(16)
    green = (Integer(color_object[:value][:grain][:value])).to_s(16)
    blue  = (Integer(color_object[:value][:blue][:value])).to_s(16)
    red   = '0' + red if red.length < 2
    green = '0' + green if green.length < 2
    blue  = '0' + blue if blue.length < 2 

    '#' + red + green + blue
  end
  
  
  def CssParser::parse_box_shadow(shadow)
    color = parse_color(shadow[:value][:color])
    size  = shadow[:value][:distance][:value]
    "#{size}px #{size}px #{size}px #{color}"
  end
  
  def CssParser::parse_opacity(layer)
    if Integer(layer[:opacity][:value]) < 255
      opacity = Float(layer[:opacity][:value])/256.0
      { :opacity => opacity.sigfig(2) }
    else
      {}
    end
    
  end
  
  
  # Returns a hash for CSS styles
  def CssParser::parse_text(layer)
    text_style = layer[:textKey][:value][:textStyleRange][:value].first
    font_info  = text_style[:value][:textStyle][:value]
    
    css                 = {}
    
    # Font name
    css.update(CssTextParser::parse_font_name(layer))
        
    # Font-weight/style
    css.update(CssTextParser::parse_font_style(font_info))
    
    # Font size
    css.update(CssTextParser::parse_font_size(font_info))
    
    # Line-height
    css.update(CssTextParser::parse_text_line_height(font_info))
    
    # Letter-spacing
    css.update(CssTextParser::parse_text_letter_spacing(font_info))
    
    # Shadows 
    css.update(CssTextParser::parse_font_shadow(layer))
    
    # Opacity
    css.update(parse_opacity(layer))
    
    # Alignment
    css.update(CssTextParser::parse_text_align(layer))

    # Color
    css.update(CssTextParser::parse_text_color(text_style))
    
    css
  end
  
  
  def CssParser::parse_box_border(layer)
    if layer.has_key? :layerEffects and layer[:layerEffects][:value].has_key? :frameFX
      border = layer[:layerEffects][:value][:frameFX]
      size   = border[:value][:size][:value].to_s + 'px'
      color  = parse_color(border[:value][:color])
      {:border => "#{size} solid #{color}"}
    else
      {}
    end
  end
  
  def CssParser::parse_box_rounded_corners(layer)
    if layer.has_key? :path_items and layer[:path_items].length > 4
      radius = layer[:path_items][2][0] - layer[:path_items][1][0]
      {:'border-radius' => "#{radius}px"}
    else
      {}
    end
  end

  def CssParser::parse_box(layer)
    css                = {}
    bounds             = layer[:bounds][:value]
    css[:'min-height'] = (bounds[:bottom][:value] - bounds[:top][:value]).to_s + 'px'

    if layer.has_key? :adjustment
      css[:background]   = parse_color(layer[:adjustment][:value].first[:value][:color])
    end
    
    css.update parse_box_border(layer)
    css.update parse_box_rounded_corners(layer)
    
    css
  end

  def CssParser::to_style_string(css)
    css_string = ""
    css.each do |key,value|
      css_string += "#{key}: #{value}; "
    end
    return css_string
  end

  def CssParser::get_image_path(layer)
    if layer.is_non_smart_image?
      image_file_name = layer.layer_json[:imagePath]
    else
      image_file_name = layer.name.gsub(' ','-') + '.png'
    end
    src_image_file = "/tmp/" + image_file_name
    destination_dir = File.join CssParser::get_assets_root, "img"
    FileUtils.mkdir_p destination_dir
    FileUtils.cp src_image_file, destination_dir

    return File.join "./assets", "img", image_file_name
  end

end

def read_file
  if ARGV.length < 1
    puts "Format: ruby CssParser.rb <filename>"
  else
    filename = ARGV.first
    data = (File.open(filename)).read
    return (JSON.parse data, :symbolize_names => true)
  end
end

def parse_file(json)
  json.each do |item|
    css = {}
    if item.has_key? 'textKey'
      puts "Text item: " +  item[:name][:value]
      css = CssParser::parse_text(item)
    elsif item.has_key? 'smartObject'
      puts "Smart Object: " + item[:name][:value]
    else
      puts "Box item: " + item[:name][:value]
      css = CssParser::parse_box(item)
    end
  end
end

if __FILE__ == $0
  data = read_file()
  if data
    parse_file(data)
  end
end
