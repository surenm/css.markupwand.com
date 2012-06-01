require 'RMagick'
require 'tempfile'

# Helps to find out how grids are drawn.
# Sample screenshot : http://cl.ly/0b3x2N3I0M152G2u0u1c 
#
# Example: 
# $ rails console
# => (DrawUtil.new('/tmp/new-home.psd.json')).draw
class DrawUtil
  attr_accessor :jsonfile_name, :canvas
  
  def initialize(jsonfile_name)
    @jsonfile_name = jsonfile_name
  end
  
  def draw_rectangle(left, top, right, bottom, opacity, stroke_size, color)
      rectangle = Magick::Draw.new
      rectangle.stroke(color)
      rectangle.fill_opacity(0)
      rectangle.stroke_width(stroke_size)
      rectangle.stroke_opacity(opacity)
      rectangle.rectangle(left, top, right, bottom)
      rectangle.draw(@canvas)
  end
  
  def draw_layer(layer)
    bounds = layer[:bounds][:value]
    
    draw_rectangle(bounds[:left][:value], bounds[:top][:value],
      bounds[:right][:value], bounds[:bottom][:value],
      0.5, 1, 'red')
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
  
  def draw_grid_bound(grid)
    if not grid.bounds.nil?
      bounds = grid.bounds
      text   = Magick::Draw.new
      text.font_family = 'helvetica'
      text.pointsize = 10
      text.fill = 'darkblue'
      text_value = "(#{bounds.width}x#{bounds.height}) @ #{bounds.left},#{bounds.top}"
      text.annotate(@canvas, 0, 0, bounds.left, bounds.top + 10, text_value)
    end
  end
  
  def draw_offset_boxes
    PageGlobals.instance.offset_box_list.each do |offset_box|
      draw_rectangle(offset_box.left, offset_box.top, offset_box.right, 
        offset_box.bottom, 1, 1, 'grey')
      draw_rectangle(offset_box.left - 1, offset_box.top - 1,
        offset_box.right - 1, offset_box.bottom - 1, 1, 1, 'pink')
      draw_rectangle(offset_box.left - 2, offset_box.top - 2,
        offset_box.right - 2, offset_box.bottom - 2, 1, 1, 'grey')
    end
  end
  
  def draw_grids(grid)
    if not grid.bounds.nil?
      bounds = grid.bounds
      draw_rectangle(bounds.left, bounds.top, bounds.right, bounds.bottom,
        1, 1, 'blue')
      
      print "."
      draw_grid_bound(grid)
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
      node = Layer.create_from_raw_data node_json
      nodes.push node
    end
    
    Grid.reset_grouping_queue
    
    user = User.find_by_email 'bot@goyaka.com'
    design = Design.new :processed_file_path => @jsonfile_name
    design.user = user
    design.save!
    design.parse
    
    draw_grids(design.grids.where(:root => true).first)
    
    Log.info "Drawing offset boxes"
    draw_offset_boxes
    
    Log.info "Drawing borders"
    canvas.border!(2, 2, "#000")
    
    tmp_file = '/tmp/' + ['gridinspect-', Random.rand(10000).to_s(16) ,'.png'].join("")
    @canvas.write(tmp_file)
    Log.info "Written to #{tmp_file}"
    system("open #{tmp_file}")
  end
end