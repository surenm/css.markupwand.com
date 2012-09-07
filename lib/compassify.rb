module Compassify
  def Compassify::get_scss(style_object)
    css_rules = []
    style_object.each do |key, object|
      if Compassify.respond_to? key
        css_rules.push Compassify.send key, object
      else
        css_rules.push "#{key} : #{object};"
      end
    end

    css_rules
  end

  # http://compass-style.org/examples/compass/css3/box_shadow/
  def Compassify::box_shadow(object)
    "@include box-shadow(#{object[:color]} #{object[:horizontal_offset]} #{object[:vertical_offset]} #{object[:blur]} #{object[:spread]} #{object[:type]})"
  end

  def Compassify::solid_fill(object)
    "background-color: #{object}"
  end

  def Compassify::gradient_fill(object)
    if object[:type] == 'linear'
      "@include background-image(linear-gradient(#{object[:angle]}deg, #{object[:color_stops].join ', '}))"
    else
      nil
    end
  end
end
