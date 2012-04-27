# Runs through nodejs.
# Format: ruby converter.rb <filename>
require 'rubygems'
require 'json'
require 'pp'

FONT_WEIGHT = {
  'Regular' => nil,
  'Bold'    => 'bold'
}

def read_file
  if ARGV.length < 1
    puts "Format: ruby converter.rb <filename>"
  else
    filename = ARGV.first
    data = (File.open(filename)).read
    return (JSON.parse data)
  end
end

def parse_color(color_object)
  red   = Integer (color_object['value']['red']['value'])
  green = Integer (color_object['value']['grain']['value'])
  blue  = Integer (color_object['value']['blue']['value'])
  
  '#' + red.to_s(16) + green.to_s(16) + blue.to_s(16)
end

def parse_text(text_item)
  #choose first one right now
  text_style = text_item['textKey']['value']['textStyleRange']['value'].first
  css        = {}
  css['font-family'] = text_style['value']['textStyle']['value']['fontName']['value']
  css['font-size']   = text_style['value']['textStyle']['value']['size']['value'].to_s + 'pt'
  font_weight        = text_style['value']['textStyle']['value']['fontStyleName']['value']
  if not FONT_WEIGHT[font_weight].nil?
    css['font-weight'] = FONT_WEIGHT[font_weight]
  end
  css['color'] = parse_color(text_style['value']['textStyle']['value']['color'])
  
  css
end

def parse_box(box_item)
  puts box_item['name']['value']
  css = {}
  bounds = box_item['bounds']['value']
  css['width'] = (bounds['right']['value'] - bounds['left']['value']).to_s + 'px'
  css['min-height'] = (bounds['bottom']['value'] - bounds['top']['value']).to_s + 'px'
  
  css
end

def parse_file(json)
  json.each do |item|
    css = {}
    if item.has_key? 'textKey'
      puts "Text item: " +  item['name']['value']
      css = parse_text(item)
    elsif item.has_key? 'smartObject'
      puts "Smart Object: " + item['name']['value']
      css = parse_box(item)
    else
      puts "Box item: " + item['name']['value']
      css = parse_box(item)
    end
    
    pp css
  end
end

data = read_file()
if data
  parse_file(data)
end