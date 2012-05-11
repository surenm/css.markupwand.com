# Runs through nodejs.
# Format: ruby converter.rb <filename>
require 'rubygems'
require 'json'
require 'pp'

module Converter
  Converter::FONT_WEIGHT = {
    'Regular' => nil,
    'Bold'    => 'bold'
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
  
  def Converter::parse_font(font)
    if Converter::FONT_MAPS.has_key? font
      Converter::FONT_MAPS[font]
    else
      return font
    end
  end
  
  def Converter::parse_shadow(shadow)
    color = parse_color(shadow[:value][:color])
    size  = shadow[:value][:distance][:value]
    "#{size}px #{size}px #{size}px #{color}"
  end
  
  def Converter::parse_opacity(opacity)
    Float(opacity[:value])/256.0
  end
  
  def Converter::parse_text(layer)
    text_style = layer[:textKey][:value][:textStyleRange][:value].first

    css                 = {}
    css[:'font-family'] = parse_font(text_style[:value][:textStyle][:value][:fontName][:value])
    css[:'font-size']   = text_style[:value][:textStyle][:value][:size][:value].to_s + 'px'
    font_weight         = text_style[:value][:textStyle][:value][:fontStyleName][:value]
    
    if layer.has_key? :layerEffects and layer[:layerEffects][:value].has_key? :dropShadow
      css[:'text-shadow'] = parse_shadow(layer[:layerEffects][:value][:dropShadow])
    end
    
    if Integer(layer[:opacity][:value]) < 255
      css[:opacity] = parse_opacity(layer[:opacity])
    end

    if not FONT_WEIGHT[font_weight].nil?
      css[:'font-weight'] = FONT_WEIGHT[font_weight]
    end
    
    css[:color] = parse_color(text_style[:value][:textStyle][:value][:color])

    css
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
