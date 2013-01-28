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
#{layer.to_scss}
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
      layer_class_name = ".#{layer_class_names[layer.type]}-#{layer.uid}"
      css = css_parser.find_by_selector layer_class_name
      if not css.first.nil?
        design.sif.layers[uid].css_rules = css.first.gsub! '; ', ";\n"
      end
    end
    design.sif.save!
    return
  end

  
end