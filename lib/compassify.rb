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

    return css_rules
  end

  # http://compass-style.org/examples/compass/css3/box_shadow/
  def Compassify::box_shadow(object)
    "@include box-shadow(#{object[:color]} #{object[:horizontal_offset]} #{object[:vertical_offset]} #{object[:blur]} #{object[:spread]} #{object[:type]});"
  end
end
