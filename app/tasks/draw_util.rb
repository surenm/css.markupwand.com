require 'RMagick'
class DrawUtil
  def initialize(jsonfile_name)
    @jsonfile_name = jsonfile_name
  end
  def draw
    json_fh     = File.read @jsonfile_name
    json_data = JSON.parse json_fh, :symbolize_names => true
    
    canvas = Magick::ImageList.new
    canvas.new_image(json_data[:properties][:width], json_data[:properties][:height], Magick::HatchFill.new('white', 'gray90'))
    json_data[:art_layers].each do |lyr|
      lyr = lyr.second
      bounds = lyr[:bounds]
      rectangle = Magick::Draw.new
      rectangle.stroke('tomato')
      rectangle.fill_opacity(0)
      rectangle.stroke_width(2)
      puts bounds
      rectangle.rectangle(bounds[:value][:left][:value], bounds[:value][:top][:value], bounds[:value][:right][:value], bounds[:value][:bottom][:value])
      rectangle.draw(canvas)
    end
    canvas.display
  end
end