require 'RMagick'
class DrawUtil
  def initialize(jsonfile_name)
    @jsonfile_name = jsonfile_name
  end
  
  def draw_layer(layer, canvas)
    bounds = layer[:bounds]
    rectangle = Magick::Draw.new
    rectangle.stroke('tomato')
    rectangle.fill_opacity(0)
    rectangle.stroke_width(2)
    rectangle.rectangle(bounds[:value][:left][:value], bounds[:value][:top][:value], bounds[:value][:right][:value], bounds[:value][:bottom][:value])
    Log.info "Drawing #{layer[:name][:value]}"
    rectangle.draw(canvas)
  end
  
  def draw_layer_name(layer, canvas)
    bounds = layer[:bounds]
    text   = Magick::Draw.new
    text.font_family = 'helvetica'
    text.pointsize = 52
    text.fill = 'red'
    Log.info "Drawing " + layer[:name][:value]
    text.annotate(canvas, bounds[:value][:left][:value], bounds[:value][:top][:value], 0, 0, layer[:name][:value])
  end
  
  def draw
    json_fh     = File.read @jsonfile_name
    json_data   = JSON.parse json_fh, :symbolize_names => true
    
    bg_original ="#{@jsonfile_name.sub '.json', ''}.png"
    
    canvas = Magick::ImageList.new
    
    if File.exists? bg_original
      bg_blob = File.open(bg_original).read
      canvas.from_blob bg_blob
    else
      canvas.new_image(json_data[:properties][:width], json_data[:properties][:height], Magick::HatchFill.new('white', 'gray90'))
    end
    
    json_data[:art_layers].each do |layer|
      draw_layer(layer.second, canvas)
    end
    canvas.display
  end
end