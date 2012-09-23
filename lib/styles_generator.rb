class StylesGenerator
  def self.get_styles(layer)
    case layer.type
    when Layer::LAYER_TEXT
      return StylesGenerator.get_text_styles(layer)
    when Layer::LAYER_SHAPE
      return StylesGenerator.get_shape_styles(layer)
    when Layer::LAYER_NORMAL
      return StylesGenerator.get_normal_styles(layer)
    end
  end

  def self.get_text_styles(layer)
    css_rules = []

    # Todo: color_overlay > gradient_overlay > pattern_overlay
    
    layer.styles.each do |rule_key, rule_object|
      case rule_key
      when :solid_fill
        css_rule = Compassify::get_scss(:text_color_overlay, rule_object)
      when :gradient_fill
        css_rule = Compassify::get_scss(:text_gradient, rule_object)
      when :shadows
        css_rule = Compassify::get_scss(:text_shadow, rule_object)
      else
        css_rule = Compassify::get_scss(rule_key, rule_object)
      end

      css_rules.push css_rule
    end
    
    css_rules.flatten!

    return css_rules
  end

  def self.get_shape_styles(layer)
    css_rules = []
    
    # TODO: color_overlay > gradient_overlay > pattern_overlay > solid color fill > gradient fill. Handle opacity ranges also
    layer.styles.each do |rule_key, rule_object|
      case rule_key
      when :solid_fill
        css_rule = Compassify::get_scss(:solid_fill, rule_object)
      when :gradient_fill
        css_rule = Compassify::get_scss(:gradient_fill, rule_object)
      when :pattern_fill
        css_rule = Compassify::get_scss(:pattern_fill, rule_object)
      when :solid_overlay
        css_rule = Compassify::get_scss(:solid_overlay, rule_object)
      when :gradient_overlay
        css_rule = Compassify::get_scss(:gradient_overlay, rule_object)
      when :pattern_overlay
        css_rule = Compassify::get_scss(:pattern_overlay, rule_object)
      when :shadows
        css_rule = Compassify::get_scss(:box_shadow, rule_object)
      when :border
        css_rule = Compassify::get_scss(:border, rule_object)
      else
        css_rule = Compassify::get_scss(rule_key, rule_object)
      end

      css_rules.push css_rule
    end

    if layer.shape[:type] == "ROUNDED_RECTANGLE"
      css_rules.push Compassify::border_radius layer.shape
    end
    
    css_rules.flatten!

    return css_rules
  end

  def self.get_normal_styles(layer)
    parsed_styles = []
    
    layer.styles.each do |style_type, style_value|
    end

    return parsed_styles
  end
end