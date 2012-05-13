# Runs through nodejs.
# Format: ruby converter.rb <filename>
require 'rubygems'
require 'json'
require 'pp'

# Modify float to cut off to few significant digits
class Float
  def sigfig(digits)
    sprintf("%.#{digits - 1}e", self).to_f
  end
end

module Converter
  Converter::FONT_WEIGHT = {
    'Regular' => nil,
    'Bold'    => 'bold'
  }
  
  Converter::FONT_STYLE = {
    'Italic' => 'italic'
  }
  
  
  Converter::FONT_MAPS  = {
    'Helvetica World' => 'Helvetica'
  }
  
  def Converter::parse_color(color_object)
    red   = (Integer(color_object[:value][:red][:value])).to_s(16)
    green = (Integer(color_object[:value][:grain][:value])).to_s(16)
    blue  = (Integer(color_object[:value][:blue][:value])).to_s(16)
    red   = '0' + red if red.length < 2
    green = '0' + green if green.length < 2
    blue  = '0' + blue if blue.length < 2 

    '#' + red + green + blue
  end
  
  def Converter::parse_font_name(font_item)
    font        = font_item[:fontName][:value]
    mapped_font = font
    if Converter::FONT_MAPS.has_key? font
      mapped_font = Converter::FONT_MAPS[font]
    end
    
    {:'font-family' => mapped_font}
  end
  
  def Converter::parse_font_size(font_item)
    { :'font-size' => font_item[:size][:value].to_s + 'px' }
  end
  
  def Converter::parse_font_style(font_item)
    font_modifier = font_item[:fontStyleName][:value]
    font_modifier_css = {}
    
    if not FONT_WEIGHT[font_modifier].nil?
      font_modifier_css[:'font-weight'] = FONT_WEIGHT[font_modifier]
    end
    
    if not FONT_STYLE[font_modifier].nil?
      font_modifier_css[:'font-style'] = FONT_STYLE[font_modifier]
    end
    
    font_modifier_css
  end
  
  def Converter::parse_font_shadow(layer)
    
    if layer.has_key? :layerEffects and layer[:layerEffects][:value].has_key? :dropShadow
      {:'text-shadow' =>
         parse_box_shadow(layer[:layerEffects][:value][:dropShadow]) }
    else
      {}
    end
  end
  
  def Converter::parse_box_shadow(shadow)
    color = parse_color(shadow[:value][:color])
    size  = shadow[:value][:distance][:value]
    "#{size}px #{size}px #{size}px #{color}"
  end
  
  def Converter::parse_opacity(layer)
    if Integer(layer[:opacity][:value]) < 255
      opacity = Float(layer[:opacity][:value])/256.0
      { :opacity => opacity.sigfig(2) }
    else
      {}
    end
    
  end
  
  def Converter::parse_text_color(text_style)
    color_object = text_style[:value][:textStyle][:value][:color]
    
    { :color => parse_color(color_object) }
  end
  
  # Returns a hash for CSS styles
  def Converter::parse_text(layer)
    text_style = layer[:textKey][:value][:textStyleRange][:value].first
    font_info  = text_style[:value][:textStyle][:value]
    
    css                 = {}
    
    # Font name
    css.update(parse_font_name(font_info))    
    
    # Font-weight/style
    css.update(parse_font_style(font_info))
    
    # Font size
    css.update(parse_font_size(font_info))
    
    
    # Shadows 
    css.update(parse_font_shadow(layer))
    
    # Opacity
    css.update(parse_opacity(layer))

    # Color
    css.update(parse_text_color(text_style))
    
    css
  end
  
  
  def Converter::parse_box_border(layer)
    if layer[:layerEffects][:value].has_key? :frameFX
      border = layer[:layerEffects][:value][:frameFX]
      size   = border[:value][:size][:value].to_s + 'px'
      color  = parse_color(border[:value][:color])
      {:border => "#{size} solid #{color}"}
    else
      {}
    end
  end
  

  def Converter::parse_box(layer)
    css                = {}
    bounds             = layer[:bounds][:value]
    css[:width]        = (bounds[:right][:value] - bounds[:left][:value]).to_s + 'px'
    css[:'min-height'] = (bounds[:bottom][:value] - bounds[:top][:value]).to_s + 'px'

    if layer.has_key? :adjustment
      css[:background]   = parse_color(layer[:adjustment][:value].first[:value][:color])
    end

    css
  end

  def Converter::to_style_string(css)
    css_string = ""
    css.each do |key,value|
      css_string += "#{key}: #{value}; "
    end
    return css_string
  end

  def Converter::get_image_path(layer)
    file = layer[:smartObject][:value][:fileReference][:value]

    "/tmp/"+ file
  end

end

def read_file
  if ARGV.length < 1
    puts "Format: ruby converter.rb <filename>"
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
      css = Converter::parse_text(item)
    elsif item.has_key? 'smartObject'
      puts "Smart Object: " + item[:name][:value]
    else
      puts "Box item: " + item[:name][:value]
      css = Converter::parse_box(item)
    end

    pp css
  end
end

if __FILE__ == $0
  data = read_file()
  if data
    parse_file(data)
  end
end
