# This should be moved to somewhere
# equivalent of SIF Root - which holds the reference for the file.
#
# 
class Sif
  class SifParseError < Exception
=begin
    TODO: Parse error could happen when there is unexpected data structure, missing key etc.
    So raise appropriate errors when that happens

=end
  end

  attr_accessor :header
  attr_accessor :layers
  attr_accessor :grids
  attr_accessor :design
  
  def self.write(design, sif_data)
    sif_file = File.join design.store_key_prefix, "#{design.safe_name_prefix}.sif"
    Store.write_contents_to_store sif_file, sif_data.to_json
  end
  
  # SIF is Smart Interface Format
  def initialize(design)
    # Appends design data with design's properties
    @design = design

    sif_file_path = File.join design.store_key_prefix, "#{design.safe_name_prefix}.sif"
    sif_file = Store::fetch_object_from_store sif_file_path
    sif_content = File.read sif_file

    # This is equivalent of a db connection pool -
    # all writes to this file go through this.
    @sif_data = JSON.parse sif_content, :symbolize_names => true, :max_nesting => false
    raise SifParseError if @sif_data.empty? or @sif_data.nil?
    
    self.parse
  end
  
  def validate
    # Validate the objects in sif object
    root_count = 0
    if not @grids.nil?
      @grids.values.each do |grid|
        root_count = root_count + 1 if grid.root
      end
    end
    
    if root_count > 1
      raise "More than one root node in grids"
    end
  end
  
  def parse
    begin
      self.parse_header
      self.parse_layers
      self.parse_grids
      self.validate
    rescue Exception => e
      raise e 
    end
  end
  
  def parse_header
    @header = @sif_data[:header]
    @design_metadata = @header[:design_metadata]
    @user_metadata = @header[:user_metada]
  end
  
  def parse_layers
    serialized_layers_arr = @sif_data[:layers]
    if serialized_layers_arr.nil?
      # If the layers are nil, then there is nothing to do.
      raise "Layers data is Nil"
    end
    
    @serialized_layers = Hash.new
    serialized_layers_arr.each { |layer_data| @serialized_layers[layer_data[:uid]] = layer_data }

    @layers = Hash.new
    @serialized_layers.each do |uid, serialized_layer_data|
      layer = self.create_layer serialized_layer_data
      @layers[uid] = layer
    end
  end
  
  def parse_grids
    serialized_grids_arr = @sif_data[:grids]
    if serialized_grids_arr.nil?
      # If there are serialized grids then most probably the design is not yet parsed
      @grids = nil
      return
    end
    
    @serialized_grids = Hash.new
    serialized_grids_arr.each { |grid_data| @serialized_grids[grid_data[:id]] = grid_data }
    
    @grids = Hash.new
    ordered_grids = get_grids_in_order()
    ordered_grids.each do |grid_id|
      serialized_grid_data = @serialized_grids[grid_id]
      @grids[grid_id] = self.create_grid serialized_grid_data
    end

    
    @serialized_grids.values.each do |grid_data|
      children = grid_data[:children]
      grid_id = grid_data[:id]
      children.each do |child_id|
        @grids[grid_id].children[child_id] = @grids[child_id]
      end
    end
  end
  
  def get_layer(layer_id)
    return @layers[layer_id]
  end
  
  def get_grid(grid_id)
    return @grids[grid_id]
  end
  
  def set_grid(grid)
    @grids = {} if @grids.nil?
    @grids[grid.id] = grid
    self.validate
  end
  
  def save!
    self.validate
    
    serialized_layers = @layers.values
    if not @grids.nil?
      serialized_grids = @grids.values.collect do |grid|
        grid.attribute_data
      end
    end
    
    sif_document = {
      :header => @header,
      :layers => serialized_layers,
      :grids  => serialized_grids,
    }
    
    Sif.write @design, sif_document
  end
  
  def get_grids_in_order
    ordered_grids = []

    start_grid_id = nil
    @serialized_grids.values.each do |grid_data|
      start_grid_id = grid_data[:id] if grid_data[:root]
    end
    
    ordering_queue = Queue.new
    ordering_queue.push start_grid_id
    
    while not ordering_queue.empty?
      grid_id = ordering_queue.pop
      ordered_grids.push grid_id
      
      children = @serialized_grids[grid_id][:children]
      children.each { |child_id| ordering_queue.push child_id }
    end
    return ordered_grids
  end
  
  def create_layer(sif_layer_data)
    layer = Layer.new
    layer.name    = sif_layer_data[:name]
    layer.type    = sif_layer_data[:type]
    layer.uid     = sif_layer_data[:uid]
    layer.zindex  = sif_layer_data[:zindex]
    layer.bounds  = BoundingBox.create_from_attribute_data sif_layer_data[:bounds]
    layer.opacity = sif_layer_data[:opacity]
    layer.text    = sif_layer_data[:text]
    layer.shapes  = sif_layer_data[:shapes]
    layer.styles  = sif_layer_data[:styles]
    layer.computed_css = {}
    layer.design  = @design
    return layer
  end
  
  def create_grid(sif_grid_data)
    # Parent grid information. 
    # Because we are parsing grids in order, these grids would have been already instantiated
    if not sif_grid_data[:root]
      parent_grid = self.get_grid sif_grid_data[:parent]
    end

    # create grid layers hash for all layers, style layers and render layer
    grid_layers = {}
    sif_grid_data[:layers].each do |layer_id|
      grid_layers[layer_id] = self.get_layer(layer_id)
    end
    
    style_layers = {}
    sif_grid_data[:style_layers].each do |layer_id|
      grid_layers[layer_id] = self.get_layer(layer_id)
    end
    
    if not sif_grid_data[:render_layer].nil?
      render_layer = self.get_layer(sif_grid_data[:render_layer]) 
    end
    
    if not sif_grid_data[:grouping_box].nil?
      grouping_box = BoundingBox.create_from_attribute_data sif_grid_data[:grouping_box]
    end
    
    if not sif_grid_data[:offset_box].nil?
      offset_box = BoundingBox.create_from_attribute_data sif_grid_data[:offset_box]
    end
    
    args = Hash.new
    args[:id]           = sif_grid_data[:id]
    args[:parent]       = parent_grid
    args[:design]       = @design
    args[:layers]       = grid_layers.values
    args[:style_layers] = style_layers
    args[:render_layer] = render_layer
    args[:grouping_box] = grouping_box
    args[:offset_box]   = offset_box
    args[:orientation]  = sif_grid_data[:orientation]
    args[:root]         = sif_grid_data[:root]
    args[:positioned]   = sif_grid_data[:positioned]
    args[:tag]          = sif_grid_data[:tag]

    # We have not instantiated children alone. Because children grids would not have been instantiated properly
    grid = Grid.new args
    return grid
  end
end
