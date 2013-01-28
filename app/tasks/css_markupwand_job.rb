class CssMarkupwandJob
  extend Resque::Plugins::History
  @queue = :worker

  def self.perform(design_id)
    design = Design.find design_id

    layers_scss = ""
    layer_class_names = {
      Layer::LAYER_TEXT => 'text',
      Layer::LAYER_SHAPE => 'wrapper',
      Layer::LAYER_NORMAL => 'image'
    }
    
    design.layers.values.each_with_index do |layer, index|
      scss_style_string = ""
      all_layer_style_rules = layer.get_style_rules 
      if layer.type == Layer::LAYER_TEXT
        all_layer_style_rules += layer.get_text_styles
      elsif layer.type == Layer::LAYER_NORMAL
        all_layer_style_rules += layer.get_image_styles
      end
      
      all_layer_style_rules.each do |style_line|
        scss_style_string += "  " + style_line + ";\n"
      end

      layers_scss += <<SCSS
.#{layer_class_names[layer.type]}-#{index} {
#{scss_style_string}
}
SCSS
    end
  end
end