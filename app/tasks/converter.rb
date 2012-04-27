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
  
  def Converter::parse_color(color_object)
    red   = Integer (color_object[:value][:red][:value])
    green = Integer (color_object[:value][:grain][:value])
    blue  = Integer (color_object[:value][:blue][:value])

    '#' + red.to_s(16) + green.to_s(16) + blue.to_s(16)
  end
  
  def Converter::parse_text(layer)
    #choose first one right now
    text_style = layer[:textKey][:value][:textStyleRange][:value].first

    css               = {}
    css[:font-family] = text_style[:value][:textStyle][:value][:fontName][:value]
    css[:font-size]   = text_style[:value][:textStyle][:value][:size][:value].to_s + 'pt'
    font_weight       = text_style[:value][:textStyle][:value][:fontStyleName][:value]

    if not FONT_WEIGHT[font_weight].nil?
      css[:font-weight] = FONT_WEIGHT[font_weight]
    end

    css[:color] = parse_color(text_style[:value][:textStyle][:value][:color])
    css
  end

  def Converter::parse_box(layer)
    puts layer[:name][:value]

    css                = {}
    bounds             = layer[:bounds][:value]
    css[:width]        = (bounds[:right][:value] - bounds[:left][:value]).to_s + 'px'
    css[:'min-height'] = (bounds[:bottom][:value] - bounds[:top][:value]).to_s + 'px'

    if layer.has_key? :adjustment
      css[:background]   = parse_color(layer[:adjustment][:value].first[:value][:color])
    end

    css
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