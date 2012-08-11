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
    Log.debug "Setting assets path to #{assets_path}"
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
  
  
  def CssParser::parse_shadow(shadow, position = 'outer')
    opacity = if shadow[:value].has_key? :opacity and shadow[:value][:opacity][:value] < 100 
        (shadow[:value][:opacity][:value]/100.0)
      else
        nil
      end
    
    color = parse_color(shadow[:value][:color], opacity)
    size  = shadow[:value][:distance][:value]
    shadow_position = position == 'inner' ? 'inset' : ''  
    
    "#{size}px #{size}px #{size}px #{color} #{shadow_position}"
  end
  
  def CssParser::parse_box_shadow(layer)
    css = {}
    layer_json = layer.layer_json
    return css if not CssParser::layer_effects_visible(layer)
    
    shadow_value = []
    if layer_json.has_key? :layerEffects and layer_json[:layerEffects][:value].has_key? :dropShadow
      outer_shadow = CssParser::is_effect_enabled(layer_json, :dropShadow)
      if outer_shadow
        shadow_value.push parse_shadow(layer_json[:layerEffects][:value][:dropShadow])
      end
    end

    if layer_json.has_key? :layerEffects and layer_json[:layerEffects][:value].has_key? :innerShadow
      inner_shadow_enabled = CssParser::is_effect_enabled(layer_json, :innerShadow)
      if inner_shadow_enabled
        shadow_value.push parse_shadow(layer_json[:layerEffects][:value][:innerShadow], 'inner')
      end
    end

    if not shadow_value.empty?
      shadow_string = shadow_value.join ","
      css[:'box-shadow']         = shadow_string
      css[:'-webkit-box-shadow'] = shadow_string
      css[:'-moz-box-shadow']    = shadow_string
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

  def CssParser::layer_effects_visible(layer)
    if layer.layer_json.has_key? :layerFXVisible 
      layer.layer_json.extract_value :layerFXVisible, :value
    else
      false
    end
  end

  def CssParser::parse_color_overlay(layer)
    css = {}
    return css if not CssParser::layer_effects_visible(layer)

    layer_json = layer.layer_json
    if layer_json.has_key? :layerEffects and layer_json[:layerEffects][:value].has_key? :solidFill
      enabled = CssParser::is_effect_enabled(layer_json, :solidFill)

      if enabled
        color_object = layer_json.extract_value(:layerEffects, :value, :solidFill, :value, :color)
        color        = CssParser::parse_color(color_object)
        if layer.kind == Layer::LAYER_TEXT
          css[:color] = color 
        else
          css[:'background-color'] = color
        end
      end
    end

    css
  end
  
  def CssParser::get_text_chunk_style(layer, chunk_index = 0)
    layer_json = layer.layer_json
    text_style = layer_json.extract_value(:textKey, :value, :textStyleRange, :value)[chunk_index]
    font_info  = text_style.extract_value(:value, :textstyle, :value)

    css = {}

    # Font name
    css.update(CssTextParser::parse_font_name(layer, chunk_index))
        
    # Font-weight/style
    css.update(CssTextParser::parse_font_style(layer, chunk_index))
    
    # Text-color
    css.update(CssTextParser::parse_text_transform(layer, chunk_index))

    # Text-underline
    css.update(CssTextParser::parse_text_underline(layer, chunk_index))

    # Font size
    css.update(CssTextParser::parse_font_size(layer, chunk_index))

    # Color
    color_overlay  = CssParser::parse_color_overlay(layer)
    color_gradient = CssParser::parse_gradient(layer)

    if not color_overlay.empty?
      css.update(color_overlay)
    elsif not color_gradient.empty?
      css.update(color_gradient)
    else
      css.update(CssTextParser::parse_text_color(text_style))
    end

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
    effect = :frameFX
    effect_enabled = CssParser::is_effect_enabled(layer, effect)
    if layer.has_key? :layerEffects and layer[:layerEffects][:value].has_key? effect and effect_enabled
      border = layer[:layerEffects][:value][effect]
      return border[:value][:size][:value]
    end
    
    return 0
  end
  
  def CssParser::parse_box_border(layer)
    css = {}
    if layer.has_key? :layerEffects and layer[:layerEffects][:value].has_key? :frameFX
      stroke_enabled = CssParser::is_effect_enabled(layer, :frameFX)
      if stroke_enabled
        border = layer[:layerEffects][:value][:frameFX]
        size   = CssParser::box_border_width(layer).to_s + 'px'
        color  = parse_color(border[:value][:color])
        css = {:border => "#{size} solid #{color}"}
      end
    end
    return css
  end
  
  def CssParser::parse_box_rounded_corners(layer)
    path_points = []
    if layer.has_key? :path_items and layer[:path_items].has_key? :points
      path_points = layer[:path_items][:points]
    end

    if path_points.length == 8
      radius = path_points[2][0] - path_points[1][0]
      return {:'border-radius' => "#{radius}px"}
    elsif path_points.length == 6
      radius = path_points[2][0] - path_points[1][0]
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
    if layer.has_key? :adjustment and layer.has_key? :fillOpacity
      fillOpacity = layer.extract_value(:fillOpacity, :value)
      if fillOpacity != 0
        opacity = fillOpacity == 255 ?  nil : Float(fillOpacity)/256.0 
        css[:'background-color']   = parse_color(layer.extract_value(:adjustment, :value).first.extract_value(:value, :color), opacity)
      end
    end
    
    css
  end

  def CssParser::is_effect_enabled(layer_json, effect)
     layer_json.extract_value(:layerEffects, :value, effect, :value, :enabled, :value) == true
  end
  
  def CssParser::parse_gradient(layer)
    layer_json = layer.layer_json
    css = {}

    return css if not CssParser::layer_effects_visible(layer)
    
    if layer_json.has_key? :layerEffects and layer_json[:layerEffects][:value].has_key? :gradientFill
      colors = layer_json[:layerEffects][:value][:gradientFill][:value][:gradient][:value][:colors][:value]
      gradient_enabled = CssParser::is_effect_enabled(layer_json, :gradientFill)

      if gradient_enabled
        if layer.kind == Layer::LAYER_TEXT
          css[:color] = parse_color(colors.first[:value][:color])
        else
          gradient_array = []
          angle = layer_json[:layerEffects][:value][:gradientFill][:value][:angle][:value]
          gradient_array.push "#{angle}deg"
          
          colors.each do |color|
            color_hash = parse_color(color[:value][:color])
            position   = ((color[:value][:location][:value] * 100)/4096.0).round.to_s
            gradient_array.push "#{color_hash} #{position}%"
          end
          
          gradient_value = gradient_array.join ", "
          css[:'background-image'] = "-webkit-linear-gradient(#{gradient_value})"
          # FIXME Use compass here, for cross browser issues.
        end
      end
    end
    
    css
    
  end
  
  def CssParser::position_absolutely(grid)
    css =  {}
    if grid.bounds and not grid.zindex.nil?
      css[:position]  = 'absolute'
      css[:top]       = (grid.bounds.top - grid.parent.bounds.top + 1).to_s + 'px'
      css[:left]      = (grid.bounds.left - grid.parent.bounds.left + 1).to_s + 'px'
      css[:'z-index'] = grid.zindex
    end
    
    css
  end
  
  def CssParser::parse_shape(layer, grid)
    layer_json = layer.layer_json
    shape_css = nil

    path_points = []
    if layer_json.has_key? :path_items and layer_json[:path_items].has_key? :points
      path_points = layer_json[:path_items][:points]
    end

    if not path_points.empty?
      path = Shape::Path.new path_points

      css_shape = Shape.get_css_shape path
      unless css_shape.nil? or layer_json[:path_items][:num_subpaths] > 1
        shape_css = css_shape.parse layer, grid
      end
      
      if shape_css.nil?
        shape_css = {}

        # Ideally, this should come from the psd file itself.
        image_file_basename = (Store::get_safe_name(layer.name)).downcase
        image_file_name     = "#{image_file_basename}_#{layer.uid}.png"
      
        design = layer.design
        src_image_file   = Rails.root.join("tmp", "store", design.store_processed_key, image_file_name).to_s
        destination_file = File.join CssParser::get_assets_root, "img", image_file_name
        Store::save_to_store src_image_file, destination_file
      
        shape_css[:'background-image']  = "url(#{File.join "..", "img", image_file_name})"
        shape_css[:'background-repeat'] = "no-repeat"
        shape_css[:'min-height'] = "#{layer.bounds.height}px"
        shape_css[:'min-width'] = "#{layer.bounds.width}px"
      end
    end
    shape_css = {} if shape_css.nil?
    return shape_css
  end

  def CssParser::parse_box(layer, grid)
    css = {}
    
    # Min-height, pick it up from grid
    css.update(parse_box_height(layer, grid))
    
    # Box width
    css.update(parse_box_width(layer, grid))
    
    # Background-color
    # Color overlay
    color_overlay = CssParser::parse_color_overlay(layer)
    
    color_gradient = CssParser::parse_gradient(layer)


    if not color_overlay.empty?
      css.update(color_overlay)
    else
      css.update(parse_box_background_color(layer.layer_json))
    end

    # If color overlay is not set, consider gradient
    if color_overlay.empty?
      css.update(color_gradient)
    end

    # Box border
    css.update parse_box_border(layer.layer_json)
    
    # Box shadow
    css.update(parse_box_shadow(layer))
    
    # parse shape
    css.update(parse_box_rounded_corners(layer.layer_json))
    
    css
  end

  def CssParser::to_style_string(css, spaces = " ")
    css_string = ""
    i = 0
    css.each do |key,value|
      css_string += "#{spaces}#{key}: #{value};"
      i = i+1
      css_string += "\n" if i != css.length
    end
    
    css_string
  end

  def CssParser::get_image_path(layer)
    image_file_name = layer.layer_json[:imagePath]

    design = layer.design

    src_image_file   = Rails.root.join("tmp", "store", design.store_processed_key, image_file_name).to_s
    destination_file = File.join CssParser::get_assets_root, "img", image_file_name

    Store::save_to_store src_image_file, destination_file

    return File.join "./assets", "img", image_file_name
  end

  def CssParser::parse_background_image(layer, grid)
    css = {}
    css[:background] = "url('../../#{layer.image_path}') no-repeat"
    css[:'background-size'] = "100% 100%"
    if grid
      css[:width] = "#{grid.style_selector.unpadded_width}px"
      css[:height] = "#{grid.style_selector.unpadded_height}px"
    end

    css
  end

  def CssParser::create_incremental_selector
    DesignGlobals.instance.incremental_class_counter = DesignGlobals.instance.incremental_class_counter + 1
    "class#{DesignGlobals.instance.incremental_class_counter}"
  end

  # Adds to a inverted list where the key is the property and value
  # is the grid.
  def CssParser::add_to_inverted_properties(css_rules, grid)
    css_rules.each do |rule, value|
      json = ({rule => value}).to_json
      if DesignGlobals.instance.css_properties_inverted.has_key? json
        DesignGlobals.instance.css_properties_inverted[json].push grid
      else
        DesignGlobals.instance.css_properties_inverted[json] = [grid]
      end
    end
  end

  # 
  # ["{'color': 'yellow'}", "{'font-family': 'Arial'}",
  #  "{'background-color': 'green'}", "{'font-size': '2px'}"]
  # 
  # to
  # 
  # {:color => 'yellow', :'font-family' => 'Arial',
  #  :'background-color' => 'green', :'font-size' => '2px'}
  # 
  #
  # Warning 1: Changes the inner data structure
  # Warning 2: Keeps overriding any key that repeats.
  def CssParser::rule_array_to_hash(rule_array)
    rule_hash = {}
    rule_array.each do |rule_string|
      rule_object = JSON.parse rule_string, :symbolize_names => true
      rule_hash.update(rule_object.keys.first => rule_object.values.first)
    end

    rule_hash
  end

  # 
  # Opposite of rule_array_to_hash function
  #
  def CssParser::rule_hash_to_array(rule_hash)
    rule_array = []
    rule_hash.each do |rule, value|
      rule_string = ({rule => value}).to_json
      rule_array.push rule_string
    end

    rule_array
  end

end
