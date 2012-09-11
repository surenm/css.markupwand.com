module Compassify
  class << self
    def get_scss(style_object)
      css_rules = []
      style_object.each do |key, object|
        if Compassify.respond_to? key
          style_string = (Compassify.send key, object)
          css_rules.push style_string if (not style_string.nil?) and (not style_string.empty?)
        else
          css_rules.push "#{key} : #{object}"
        end
      end

      css_rules
    end

    # http://compass-style.org/examples/compass/css3/box_shadow/
    def box_shadow(shadows)
      shadow_css_items = []
      shadows.each do |shadow|
        shadow_css_items.push "#{shadow[:color]} #{shadow[:vertical_offset]} #{shadow[:horizontal_offset]} #{shadow[:blur]} #{shadow[:spread]} #{shadow[:type]}"
      end
      
      "@include box-shadow(" + shadow_css_items.join(', ') + ")"
    end    
    
    def solid_fill(object)
      "background-color: #{object}"
    end
    alias :solid_color :solid_fill

    def gradient_fill(object)
      if object[:type] == 'linear'
        "@include background-image(linear-gradient(#{object[:angle]}deg, #{object[:color_stops].join ', '}))"
      else
        nil
      end
    end
    
    def border(object)
      if object.is_a? Hash
        "border : #{object[:width]} solid #{object[:color]}"
      else
        "border : #{object}"
      end
    end

  end
end
