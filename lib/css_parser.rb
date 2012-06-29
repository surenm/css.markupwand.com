# Format: ruby CssParser.rb <filename>
require 'rubygems'
require 'json'
require 'pp'

'''
This file holds all the css parser classes
It tries to understand the photoshop json file and spits out css
Kind of a collection of helper functions
'''
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
  
  def CssParser::get_text_chunk_style(layer, chunk_index = 0)
    layer_json = layer.layer_json
    text_style = layer_json.extract_value(:textKey, :value, :textStyleRange, :value)[chunk_index]
    font_info  = text_style.extract_value(:value,:textStyle,:value)

    css = {}

    # Font name
    css.update(CssTextParser::parse_font_name(layer, chunk_index))
        
    # Font-weight/style
    css.update(CssTextParser::parse_font_style(layer, chunk_index))
    
    # Font size
    css.update(CssTextParser::parse_font_size(layer, chunk_index))

    # Color
    css.update(CssTextParser::parse_text_color(text_style))

    # Shadows 
    css.update(CssTextParser::parse_font_shadow(layer_json))

    css
  end
  
  # Returns a hash for CSS styles
  def CssParser::parse_text(layer)
    layer_json = layer.layer_json
    text_style = layer_json.extract_value(:textKey, :value, :textStyleRange, :value).first
    font_info  = text_style.extract_value(:value, :textStyle, :value)
    
    css = {}

    if not layer.has_multifont?
      css.update  CssParser::get_text_chunk_style(layer)
    end
    
    # Line-height
    css.update(CssTextParser::parse_text_line_height(layer))
    
    # Letter-spacing
    css.update(CssTextParser::parse_text_letter_spacing(font_info))
    
    # Opacity
    css.update(parse_opacity(layer_json))
    
    # Alignment
    css.update(CssTextParser::parse_text_align(layer))
    
    css
  end
  
  def CssParser::box_border_width(layer)
    if layer.has_key? :layerEffects and layer[:layerEffects][:value].has_key? :frameFX
      border = layer[:layerEffects][:value][:frameFX]
      return border[:value][:size][:value]
     else
      return 0
    end

  end
  
  def CssParser::parse_box_border(layer)
    if layer.has_key? :layerEffects and layer[:layerEffects][:value].has_key? :frameFX
      border = layer[:layerEffects][:value][:frameFX]
      size   = CssParser::box_border_width(layer).to_s + 'px'
      color  = parse_color(border[:value][:color])
      {:border => "#{size} solid #{color}"}
    else
      {}
    end
  end
  
  def CssParser::parse_box_rounded_corners(layer)
    if layer.has_key? :path_items and layer[:path_items].length == 8
      radius = layer[:path_items][2][0] - layer[:path_items][1][0]
      return {:'border-radius' => "#{radius}px"}
    elsif layer.has_key? :path_items and layer[:path_items].length == 6
      radius = layer[:path_items][2][0] - layer[:path_items][1][0]
      return {:'border-radius' => "#{radius}px"}
    else
      return {}
    end
  end
  
  def CssParser::parse_box_height(layer, grid)
    if grid.nil? and not layer.is_overlay?
      return {}
    end
    
    if layer.is_overlay?
      height = layer.bounds.height
    else
      height = grid.style_selector.unpadded_height
    end

    border_width = CssParser::box_border_width(layer.layer_json)
    height = (height - (2 * border_width)) if (border_width > 0 and not height.nil?) 

    if not height.nil?
      {:'min-height' => height.to_s + 'px' }
    else
      {}
    end
  end
  
  def CssParser::parse_box_width(layer, grid)
    if grid.nil? and not layer.is_overlay?
      return {}
    end
    
    if layer.is_overlay?
      width = layer.bounds.width
    else
      width = grid.style_selector.unpadded_width
    end

    border_width = CssParser::box_border_width(layer.layer_json)
    width = (width - (2 * border_width)) if (border_width > 0  and not width.nil?)

    if not width.nil?
      {:width => width.to_s + 'px' }
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
  
  def CssParser::position_absolutely(grid)
    css =  {}
    if grid.bounds
      css[:position]  = 'absolute'
      css[:top]       = (grid.bounds.top - grid.parent.bounds.top).to_s + 'px'
      css[:left]      = (grid.bounds.left - grid.parent.bounds.left).to_s + 'px'
      css[:'z-index'] = grid.zindex
    end
    
    css
  end
  
  def CssParser::parse_shape(layer, grid)
    layer_json = layer.layer_json
    shape_css = nil
      
    if layer_json.has_key? :path_items and not layer_json[:path_items].empty?
      if layer_json[:path_items].length == 4 
        if (layer_json[:path_items][0][1] == layer_json[:path_items][1][1]) and (layer_json[:path_items][0][0] == layer_json[:path_items][3][0])
           shape_css = CssParser::parse_box layer, grid
        end
      elsif layer_json[:path_items].length == 8
        shape_css = CssParser::parse_box layer, grid
      elsif layer_json[:path_items].length == 6
        shape_css = CssParser::parse_box layer, grid
      end
      

      if shape_css.nil?
        shape_css = {}

        image_file_basename = Store::get_safe_name(layer.name)
        image_file_name = "#{image_file_basename}_#{layer.uid}.png"
      
        design = layer.design
        src_image_file   = Rails.root.join("tmp", "store", design.store_processed_key, image_file_name).to_s
        destination_file = File.join CssParser::get_assets_root, "img", image_file_name
        Store::save_to_store src_image_file, destination_file
      
      
        shape_css[:'background-image'] = "url(#{File.join "..", "img", image_file_name})"
        shape_css[:'background-repeat'] = "no-repeat"
        shape_css[:'min-height'] = "#{layer.bounds.height}px"
        shape_css[:'min-width'] = "#{layer.bounds.width}px"
      end
    else
      shape_css = CssParser::parse_box layer, grid
    end
    return shape_css
  end

  def CssParser::parse_box(layer, grid)
    css = {}
    
    # Min-height, pick it up from grid
    css.update(parse_box_height(layer, grid))
    
    # Box width
    css.update(parse_box_width(layer, grid))
    
    # Background-color
    css.update(parse_box_background_color(layer.layer_json))

    # Box border
    css.update parse_box_border(layer.layer_json)
    
    # Box gradient 
    css.update(parse_box_gradient(layer.layer_json))
    
    # Box shadow
    css.update(parse_box_shadow(layer.layer_json))
    
    # parse shape
    css.update(parse_box_rounded_corners(layer.layer_json))
    
    css
  end

  def CssParser::to_style_string(css)
    css_string = ""
    css.each do |key,value|
      css_string += "#{key}: #{value}; "
    end
    return css_string
  end

  def CssParser::cleanup_positioning_css(css)
    positioning_symbols = [:'min-height', :width, :height, :'padding-top',
      :'padding-left', :'padding-right', :'padding-bottom', :'margin-top',
      :'margin-left', :'margin-right', :'margin-bottom']

    positioning_symbols.each do |symbol|
      css.delete symbol
    end

    css
  end

  def CssParser::get_image_path(layer)
    image_file_name = layer.layer_json[:imagePath]

    design = layer.design

    src_image_file   = Rails.root.join("tmp", "store", design.store_processed_key, image_file_name).to_s
    destination_file = File.join CssParser::get_assets_root, "img", image_file_name

    Store::save_to_store src_image_file, destination_file

    return File.join "./assets", "img", image_file_name
  end

end
