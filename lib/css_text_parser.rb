module CssTextParser
  FONT_WEIGHT = {
    'Regular' => nil,
    'Bold'    => 'bold'
  }
  
  FONT_STYLE = {
    'Italic' => 'italic'
  }
  
  TEXT_ALIGN = {
    1131312242 => 'center'
  } 
  
  def CssTextParser::parse_font_name(layer)
    mapped_font = layer.get_font_name
    if not mapped_font.nil?
      {:'font-family' => mapped_font}
    else
      {}
    end
  end
  
  def CssTextParser::parse_font_size(font_item)
    { :'font-size' => font_item[:size][:value].to_s + 'px' }
  end
  
  def CssTextParser::parse_font_style(font_item)
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
  
  def CssTextParser::parse_font_shadow(layer)
    
    if layer.has_key? :layerEffects and layer[:layerEffects][:value].has_key? :dropShadow
      {:'text-shadow' =>
         CssParser::parse_shadow(layer[:layerEffects][:value][:dropShadow]) }
    else
      {}
    end
  end
  
  def CssTextParser::parse_text_color(text_style)
    color_object = text_style.extract_value(:value, :textStyle, :value, :color)
    { :color => CssParser::parse_color(color_object) }
  end
  
  def CssTextParser::parse_text_align(layer)
    css = {}
    paragraph_style = layer.extract_value(:textKey, :value, :paragraphStyleRange, :value)
    align_code = paragraph_style.first.extract_value(:value, :paragraphStyle, :value, :align, :value)

    if !align_code.nil? and TEXT_ALIGN.has_key? align_code
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
      {:'letter-spacing' => (font_info[:tracking][:value]/20.0).round.to_s + 'px'}
    else
      {}
    end
  end
  
  
end