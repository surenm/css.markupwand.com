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
    assets_path = File.join root, "assets"
    ENV["ASSETS_DIR"] = assets_path.to_s
  end
  
  def CssParser::get_assets_root
    ENV["ASSETS_DIR"]
  end

  def CssParser::parse_color(color_object, opacity = nil)
    red   = color_object.extract_value(:value, :red, :value)
    green = color_object.extract_value(:value, :grain, :value)
    blue  = color_object.extract_value(:value, :blue, :value)
    
    if red.nil? or blue.nil? or green.nil?
      return ""
    end    
    
    red   = Integer(red)
    blue  = Integer(blue)
    green = Integer(green)
    
    if not opacity.nil?
      # Use rgb(a,b,c) format when opacity is given
      color = sprintf("rgba(%d, %d, %d, %0.2f)", red, green, blue, opacity)
    else
      # Use normal hex hash
      color = sprintf("#%02x%02x%02x", red, green, blue)
    end
    
    color
  end
  
  
  def CssParser::parse_shadow(shadow)
    opacity = if shadow[:value].has_key? :opacity and shadow[:value][:opacity][:value] < 100 
        (shadow[:value][:opacity][:value]/100.0)
      else
        nil
      end
    
    color = parse_color(shadow[:value][:color], opacity)
    size  = shadow[:value][:distance][:value]
    
    "#{size}px #{size}px #{size}px #{color}"
  end
  
  def CssParser::parse_box_shadow(layer)
    css = {}
    
    if layer.has_key? :layerEffects and layer[:layerEffects][:value].has_key? :dropShadow
      shadow_value = parse_shadow(layer[:layerEffects][:value][:dropShadow])
      css[:'box-shadow']         = shadow_value
      css[:'-webkit-box-shadow'] = shadow_value
      css[:'-moz-box-shadow']    = shadow_value
    end
    
    css
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
    layer_json = layer.layer_json
    text_style = layer_json[:textKey][:value][:textStyleRange][:value].first
    font_info  = text_style[:value][:textStyle][:value]
    
    css = {}
    
    # Font name
    css.update(CssTextParser::parse_font_name(layer))
        
    # Font-weight/style
    css.update(CssTextParser::parse_font_style(font_info))
    
    # Font size
    css.update(CssTextParser::parse_font_size(font_info))
    
    # Line-height
    css.update(CssTextParser::parse_text_line_height(layer))
    
    # Letter-spacing
    css.update(CssTextParser::parse_text_letter_spacing(font_info))
    
    # Shadows 
    css.update(CssTextParser::parse_font_shadow(layer_json))
    
    # Opacity
    css.update(parse_opacity(layer_json))
    
    # Alignment
    css.update(CssTextParser::parse_text_align(layer_json))

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
  
  def CssParser::parse_box_height(grid)
    if grid.nil?
      return {}
    end

    height = grid.unpadded_height

    if not height.nil?
      {:'min-height' => (grid.unpadded_height).to_s + 'px' }
    else
      {}
    end
  end
  
  def CssParser::parse_box_background_color(layer)
    css = {}
    if layer.has_key? :adjustment
      css[:'background-color']   = parse_color(layer[:adjustment][:value].first[:value][:color])
    end
    
    css
  end
  
  def CssParser::parse_box_gradient(layer)
    css = {}
    
    if layer.has_key? :layerEffects and layer[:layerEffects][:value].has_key? :gradientFill
      gradient_array = []
      colors = layer[:layerEffects][:value][:gradientFill][:value][:gradient][:value][:colors][:value]
      angle = layer[:layerEffects][:value][:gradientFill][:value][:angle][:value]
      gradient_array.push "#{angle}deg"
      
      colors.each do |color|
        color_hash = parse_color(color[:value][:color])
        position   = ((color[:value][:location][:value] * 100)/4096.0).round.to_s
        gradient_array.push "#{color_hash} #{position}%"
      end
      
      gradient_value = gradient_array.join ", "
      css[:'background-image'] = "-webkit-linear-gradient(#{gradient_value})"
      # FIXME Change data type of css from hash to a data structure that allows duplicate hash keys. 
      #  css[:'background-image'] = "-o-linear-gradient(#{gradient_value})"
      #  css[:'background-image'] = "-moz-linear-gradient(#{gradient_value})"
      #  css[:'background-image'] = "linear-gradient(#{gradient_value})"
    end
    
    css
    
  end
  
  def CssParser::position_absolutely(layer, grid)
    css =  {}
    if grid.bounds
      css[:position]  = 'absolute'
      css[:top]       = (layer.bounds.top - grid.bounds.top).to_s + 'px'
      css[:left]      = (layer.bounds.left - grid.bounds.left).to_s + 'px'
      css[:'z-index'] = layer.layer_json.extract_value(:itemIndex, :value)
    end
    
    css
  end

  def CssParser::parse_box(layer, grid)
    css                = {}
    
    # Min-height, pick it up from grid
    css.update(parse_box_height(layer, grid))
    
    # Background-color
    css.update(parse_box_background_color(layer.layer_json))

    # Box border
    css.update parse_box_border(layer.layer_json)
    
    # Box rounded corners
    css.update(parse_box_rounded_corners(layer.layer_json))
    
    # Box gradient 
    css.update(parse_box_gradient(layer.layer_json))
    
    # Box shadow
    css.update(parse_box_shadow(layer.layer_json))
    
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
    image_file_name = layer.layer_json[:imagePath]
    src_image_file   = "/tmp/" + image_file_name
    destination_file = File.join CssParser::get_assets_root, "img", image_file_name

    # TODO: as processed image file directory changes to Store, this changes to Store:copy
    Store::copy_from_local src_image_file, destination_file

    return File.join "./assets", "img", image_file_name
  end

end