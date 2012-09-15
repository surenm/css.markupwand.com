module Compassify
  class << self
    def get_scss(key, style_object)
      if Compassify.respond_to? key
        style_string = (Compassify.send key, style_object)
        
        if (not style_string.nil?) and (not style_string.empty?)
          return style_string
        else
          return nil 
        end 
      else
        ["#{key} : #{style_object}"]
      end
    end

    # http://compass-style.org/examples/compass/css3/box_shadow/
    def shadows(shadows)
      shadow_css_items = []
      shadows.each do |shadow_type, shadow|
        shadow = "#{shadow[:color]} #{shadow[:vertical_offset]} #{shadow[:horizontal_offset]} #{shadow[:blur]} #{shadow[:spread]}"
        if shadow_type == :inner_shadow
          shadow += " inset" 
        end
        shadow_css_items.push shadow
      end
      
      ["@include box-shadow(" + shadow_css_items.join(', ') + ")"]
    end    

    def text_shadow(shadows)
      shadow = shadows[:drop_shadow]
      if not shadow.nil?
        ["@include text-shadow(#{shadow[:color]} #{shadow[:horizontal_offset]} #{shadow[:vertical_offset]}  #{shadow[:blur]})"]
      end
    end
    
    def solid_fill(object)
      ["background-color : #{object}"]
    end
    alias :solid_color :solid_fill

    def gradient_fill(object)
      if object[:type] == 'linear'
        ["@include background-image(linear-gradient(#{object[:angle]}deg, #{object[:color_stops].join ', '}))"]
      else
        nil
      end
    end
    
    def border(object)
      if object.is_a? Hash
        ["border : #{object[:width]} solid #{object[:color]}"]
      else
        ["border : #{object}"]
      end
    end

    # This I think is still messy. Should fix it.
    def get_border_radius(radius)
      ["@include border-radius(#{radius})"]
    end

    def text_gradient(gradient)
      ["background: -webkit-linear-gradient(#{gradient[:angle]}deg, #{gradient[:color_stops].join ', '})",
       "-webkit-background-clip: text",
       "-webkit-text-fill-color: transparent"]
    end
  end
end