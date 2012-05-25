require 'RMagick'
class DrawUtil
  attr_accessor :jsonfile_name, :canvas
  
  def initialize(jsonfile_name)
    @jsonfile_name = jsonfile_name
  end
  
  def draw_layer(layer)
    bounds = layer[:bounds]
    rectangle = Magick::Draw.new
    rectangle.stroke('red')
    rectangle.fill_opacity(0)
    rectangle.stroke_width(1)
    rectangle.stroke_opacity(0.5)
    rectangle.rectangle(bounds[:value][:left][:value], bounds[:value][:top][:value], bounds[:value][:right][:value], bounds[:value][:bottom][:value])
    rectangle.draw(@canvas)
  end
  
  def draw_layer_name(layer)
    bounds = layer[:bounds]
    text   = Magick::Draw.new
    text.font_family = 'helvetica'
    text.pointsize = 10
    text.fill = 'green'
    x = bounds[:value][:left][:value]
    y = bounds[:value][:top][:value]
    text.annotate(@canvas, 0, 0, x, y, layer[:name][:value])
  end
  
  def draw_grids(grid)
    if not grid.bounds.nil?
      bounds = grid.bounds
      rectangle = Magick::Draw.new
      rectangle.stroke('blue')
      rectangle.fill_opacity(0)
      rectangle.stroke_width(1)
      rectangle.rectangle(bounds.left, bounds.top, bounds.right, bounds.bottom)
      print "."
      rectangle.draw(@canvas)
    end
    
    if grid.children.length > 0
      grid.children.each do |child|
        draw_grids(child)
      end
    end
  end
  
  def draw
    json_fh     = File.read @jsonfile_name
    json_data   = JSON.parse json_fh, :symbolize_names => true
    
    bg_original ="#{@jsonfile_name.sub '.json', ''}.png"
    
    @canvas = Magick::ImageList.new
    
    if File.exists? bg_original
      bg_blob = File.open(bg_original).read
      @canvas.from_blob bg_blob
    else
      @canvas.new_image(json_data[:properties][:width], json_data[:properties][:height], Magick::HatchFill.new('white', 'gray90'))
    end
    
    art_layers = json_data[:art_layers]
    
    
    art_layers.each do |layer|
      Log.info "Drawing #{layer.second[:name][:value]}"
      draw_layer(layer.second)
      draw_layer_name(layer.second)
    end
    
    #Set page level properties
    pageglobals = PageGlobals.instance
    pageglobals.page_bounds = BoundingBox.new(0, 0,
      json_data[:properties][:height], json_data[:properties][:width])
    
    
    nodes = []
    art_layers.each do |layer_id, node_json|
      node = Layer.new
      node.set node_json
      nodes.push node
    end
    
    Grid.reset_grouping_queue
    
    Log.info "Creating grids..."
    grid = Grid.new 
    grid.set nodes, nil
    
    Grid.group!
    Log.info "Drawing grids..."
    draw_grids(grid)
    Log.info "done"
    @canvas.display
  end
end