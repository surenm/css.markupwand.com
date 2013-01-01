module Compassify
  class << self

    def get_scss(key, style_object)
      if Compassify.respond_to? key
        style_string = (Compassify.send key, style_object)
        
        if not style_string.nil?
          return style_string
        else
          return nil 
        end 
      else
        ["#{key}: #{style_object}"]
      end
    end

    ################################
    # Handle Shape fills and their overlays 
    ################################
    def solid_fill(object)
      ["background-color : #{object}"]
    end

    def gradient_fill(object)
      if object[:type] == 'linear'
        ["@include background-image(linear-gradient(#{object[:angle]}deg, #{object[:color_stops].join ', '}))"]
      end
    end

    def pattern_fill(object)
      #TODO: Extract pattern from psd and make it as repeat background image here
      return []
    end

    # http://compass-style.org/examples/compass/css3/box_shadow/
    def box_shadow(shadows)
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

    #####################################
    # Handle border related information
    #####################################
    
    def border(object)
      if object.is_a? Hash
        ["border : #{object[:width]} solid #{object[:color]}"]
      else
        ["border : #{object}"]
      end
    end

    def border_radius(shape)
      ["@include border-radius(#{shape[:curvature]})"]
    end

    alias :solid_overlay :solid_fill
    alias :gradient_overlay :gradient_fill
    alias :pattern_overlay :pattern_fill

    ################################
    # Handle text color, shadows
    ################################
    def text_shadow(shadows)
      shadow = shadows[:drop_shadow]
      if not shadow.nil?
        ["@include text-shadow(#{shadow[:color]} #{shadow[:horizontal_offset]} #{shadow[:vertical_offset]}  #{shadow[:blur]})"]
      end
    end
    
    def text_color_overlay(object)
      ["color: #{object}"]
    end

    def text_gradient_overlay(gradient)
      ["color: #{gradient[:color_stops].first.split(' ').first}"]
=begin this craps out text shadow for now. Hence disabling.
      ["background: -webkit-linear-gradient(#{gradient[:angle]}deg, #{gradient[:color_stops].join ', '})",
       "-webkit-background-clip: text",
       "-webkit-text-fill-color: transparent"]
=end
    end

    def styles_hash_to_array(styles_hash)
      styles_array = styles_hash.collect do |rule_key, rule_value|
        Compassify::get_scss rule_key, rule_value
      end

      return styles_array
    end

    def scss_to_css(styles_array)
      scss_style_string = <<BEGIN
@import "compass";
@import "compass/css3";
@import "compass/css3/box-shadow";
@import "compass/css3/border-radius";

.element { 
BEGIN
      styles_array.each do |style_line|
        scss_style_string += style_line + ";\n"
      end
      scss_style_string += "}"

      scss_engine = Sass::Engine.new scss_style_string, { 
        :load_paths => Constants::COMPASS_CONFIG, 
        :syntax => :scss, 
        :cache_location => Rails.root.join('tmp').to_s
      }
      
      css_style_rules = scss_engine.render
      matches = /\.element {(?<css>[\s\S]*)}/.match(css_style_rules)
      if not matches.nil?
        return matches["css"]
      end

      return ""
    end
  end
end