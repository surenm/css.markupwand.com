module CssTextParser
  FONT_WEIGHT = {
    'Regular' => nil,
    'Bold'    => 'bold',
    'Bold Italic'    => 'bold',
    'BoldItalic'  => 'bold'
  }
  
  FONT_STYLE = {
    'Italic' => 'italic',
    'Bold Italic'    => 'italic',
    'BoldItalic' => 'italic'
  }
  
  TEXT_ALIGN = {
    1131312242 => 'center',
    1281713780 => 'left',
    1382508660 => 'right'
  }

  TEXT_TRANSFORM = {
    1316121964 => 'none',
    1621       => 'uppercase'
  }


  def CssTextParser::parse_text_transform(layer, position = 0)
    text_style     = layer.layer_json.extract_value(:textKey, :value, :textStyleRange, :value)[position]
    font_caps      = text_style.extract_value(:value, :textStyle, :value, :fontCaps, :value)

    if TEXT_TRANSFORM[font_caps] != 'none' and not TEXT_TRANSFORM[font_caps].nil?
      {:'text-transform' => TEXT_TRANSFORM[font_caps]}
    else
      {}
    end
  end
  
  def CssTextParser::parse_font_name(layer, position = 0)
    mapped_font = layer.get_font_name(position)
    if not mapped_font.nil?
      {:'font-family' => mapped_font}
    else
      {}
    end
  end
  
  def CssTextParser::parse_font_size(layer, position = 0)
    text_style = layer.layer_json.extract_value(:textKey, :value, :textStyleRange, :value)[position]
    font_item  = text_style.extract_value(:value,:textStyle,:value)

    font_in_px = (font_item[:size][:value]).to_i 
    { :'font-size' => "#{font_in_px}px" }
  end
  
  def CssTextParser::parse_font_style(layer, position = 0)
    text_style = layer.layer_json.extract_value(:textKey, :value, :textStyleRange, :value)[position]
    font_info  = text_style.extract_value(:value,:textStyle,:value)

    font_modifier = font_info.extract_value(:fontStyleName, :value)
    font_modifier_css = {}
    
    if not FONT_WEIGHT[font_modifier].nil?
      font_modifier_css[:'font-weight'] = FONT_WEIGHT[font_modifier]
    end
    
    if not FONT_STYLE[font_modifier].nil?
      font_modifier_css[:'font-style'] = FONT_STYLE[font_modifier]
    end
    
    font_modifier_css
  end
  
  def CssTextParser::parse_font_shadow(layer)
    
    if layer.has_key? :layerEffects and layer[:layerEffects][:value].has_key? :dropShadow
      {:'text-shadow' =>
         CssParser::parse_shadow(layer[:layerEffects][:value][:dropShadow]) }
    else
      {}
    end
  end
  
  def CssTextParser::parse_text_color(text_style)
    color = ""
    color_object = text_style.extract_value(:value, :textStyle, :value, :color) unless text_style.nil?
    color = CssParser::parse_color(color_object) if not color_object.nil?
    { :color =>  color }
  end
  
  def CssTextParser::parse_text_align(layer)
    css = {}
    paragraph_style = layer.layer_json.extract_value(:textKey, :value, :paragraphStyleRange, :value)
    align_code = paragraph_style.first.extract_value(:value, :paragraphStyle, :value, :align, :value) unless paragraph_style.nil? or paragraph_style.first.nil?

    if !align_code.nil? and TEXT_ALIGN.has_key? align_code and layer.has_newline?
      css[:'text-align'] = TEXT_ALIGN[align_code]
    end
    
    css
  end
  
  def CssTextParser::parse_text_line_height(layer)
    # Reference: http://help.adobe.com/en_US/photoshop/cs/using/WS5EC229CC-1518-4f06-BCB0-E2585D61FC54a.html#WSfd1234e1c4b69f30ea53e41001031ab64-75a4a
    
    layer_json = layer.layer_json
    text_style = layer_json[:textKey][:value][:textStyleRange][:value].first
    font_info  = text_style[:value][:textStyle][:value]
    
    if not font_info[:leading].nil? and layer.has_newline?
      {:'line-height' => font_info[:leading][:value].to_s + 'px'}
    else
      {}
    end
  end

  def CssTextParser::parse_text_letter_spacing(font_info)
    #Same reference as above
    if not font_info[:tracking].nil? and font_info[:tracking] != 0
      letter_spacing = (font_info[:tracking][:value]/20.0).round

      if letter_spacing != 0
        {:'letter-spacing' => (font_info[:tracking][:value]/20.0).round.to_s + 'px'}
      else
        {}
      end
    else
      {}
    end
  end
  
  
end