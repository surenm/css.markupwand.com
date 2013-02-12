require 'css_parser'
include CssParser

class CssMarkupwandJob
  extend Resque::Plugins::History
  @queue = :worker

  def self.perform(design_id)
    design = Design.find design_id

    layers_scss = '@import "compass";'
    layer_class_names = {
      Layer::LAYER_TEXT => 'text',
      Layer::LAYER_SHAPE => 'wrapper',
      Layer::LAYER_NORMAL => 'image'
    }
    
    design.layers.each do |uid, layer|
      layers_scss += <<SCSS
.#{layer_class_names[layer.type]}-#{uid} {
#{layer.to_scss(false)}
}
SCSS
    end
    
    scss_engine = Sass::Engine.new layers_scss, { 
      :load_paths => Constants::COMPASS_CONFIG, 
      :syntax => :scss, 
      :cache_location => Rails.root.join('tmp').to_s
    }
    
    layers_css = scss_engine.render
    css_parser = CssParser::Parser.new
    css_parser.add_block! layers_css

    design.layers.each do |uid, layer|
      if layer.type != Layer::LAYER_TEXT
        layer_class_name = ".#{layer_class_names[layer.type]}-#{layer.uid}"
        css = layers_css.match /#{layer_class_name} {(?<content>[^}]*)}/
        if not css.nil?
          design.sif.layers[uid].css_rules = Utils::indent_scss css[:content]
        end
      else 
        text_layer_css = ""
        layer.text_chunks.each_with_index do |chunk, index|
          next if chunk[:text].size == 0
          layer_class_name = ".#{layer_class_names[layer.type]}-#{layer.uid} .text-chunk-#{index}"
          css = layers_css.match /#{layer_class_name} {(?<content>[^}]*)}/
          if not css.nil?
            snippet = Utils::get_snippet chunk[:text]
            text_layer_css += "\n/* Style for: #{snippet} */\n"
            text_layer_css += Utils::indent_scss css[:content]
          end
        end
        design.sif.layers[uid].css_rules = text_layer_css
      end
    end
    design.sif.save!

    return
  end
end