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

def parse_fonts(text_item)
  #choose first one right now
  text_style = text_item['textKey']['value']['textStyleRange']['value'].first
  css        = {}
  css['font-family'] = text_style['value']['textStyle']['value']['fontName']['value']
  css['font-size']   = text_style['value']['textStyle']['value']['size']['value']
  font_weight        = text_style['value']['textStyle']['value']['fontStyleName']['value']
  if not FONT_WEIGHT[font_weight].nil?
    css['font-weight'] = FONT_WEIGHT[font_weight]
  end
  
  css
end

def parse_file(json)
  json.each do |item|
    if item.has_key? 'textKey'
      puts item['name']['value']
      fonts = parse_fonts(item)
      pp fonts
    end
  end
end

data = read_file()
if data
  parse_file(data)
end