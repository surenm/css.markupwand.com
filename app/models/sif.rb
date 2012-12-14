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
  
  attr_accessor :design
  attr_accessor :header
  attr_accessor :layers
  attr_accessor :root_grid
  attr_accessor :root_grouping_box
  
  def self.write(design, sif_data)
    sif_file = design.get_sif_file_path
    Store.write_contents_to_store sif_file, sif_data.to_json
  end
  
  # SIF is Smart Interface Format
  def initialize(design)
    # Appends design data with design's properties
    @design = design

    sif_file_path = @design.get_sif_file_path
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
      self.parse_grouping_boxes
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

  def parse_grouping_boxes
    serialized_root_grouping_box = @sif_data[:root_grouping_box]
    if serialized_root_grouping_box.nil?
      # If there are serialized grids then most probably the design is not yet parsed
      @grouping_boxes = nil
      return
    end

    @root_grouping_box = self.create_grouping_box serialized_root_grouping_box
  end
  
  def parse_grids
    serialized_root_grid = @sif_data[:root_grid]
    if serialized_root_grid.nil?
      # If there are serialized grids then most probably the design is not yet parsed
      @root_grid = nil
      return
    end
    
    @root_grid = self.create_grid serialized_root_grid
    
  end

  # Grids are not availabe when layers are created.
  # Once both Grids and Layers are created, create parent values for layers
  def get_layer(layer_id)
    return @layers[layer_id]
  end
  
  def reset_grids
    @root_grid = nil
    self.save!
  end

  def reset_calculated_data
    @root_grouping_box = nil
    @root_grid = nil
    @layers.each do |layer_id, layer|
      @layers[layer_id].grouping_box = nil
    end
    self.save!
  end

  def get_serialized_data
    self.validate

    if not @root_grouping_box.nil?
      serialized_root_grouping_box = @root_grouping_box.attribute_data
      # Set the grouping box for layers. 
      @root_grouping_box.each do |grouping_box|
        if grouping_box.is_leaf?
          # If leaf node all this layers belong to this grouping box
          grouping_box.layers.each do |layer|
            @layers[layer.uid].grouping_box = grouping_box.bounds
          end
        else
          # If not leaf node, only style nodes belong to this grouping box
          grouping_box.style_layers.each do |style_layer|
            @layers[style_layer.uid].grouping_box = grouping_box.bounds
          end
        end
      end
    end

    if not @root_grid.nil?
      serialized_root_grid = @root_grid.attribute_data
    end

    serialized_layers = @layers.values.collect do |layer|
      layer.attribute_data
    end

    sif_document = {
      :header => @header,
      :layers => serialized_layers,
      :root_grouping_box => serialized_root_grouping_box,
      :root_grid => serialized_root_grid,
    }
  end

  def save!
    serialized_document = self.get_serialized_data
    Sif.write @design, serialized_document
  end
  
  def create_layer(sif_layer_data)
    layer = Layer.new
    layer.name = sif_layer_data[:name]
    layer.type = sif_layer_data[:type]
    layer.uid = sif_layer_data[:uid]
    layer.zindex = sif_layer_data[:zindex]
    if sif_layer_data[:initial_bounds].nil?
      layer.initial_bounds = BoundingBox.create_from_attribute_data sif_layer_data[:bounds]
    else
      layer.initial_bounds = BoundingBox.create_from_attribute_data sif_layer_data[:initial_bounds]
    end
    design_bounds = BoundingBox.new 0, 0, @header[:design_metadata][:height], @header[:design_metadata][:width]
    layer.bounds = layer.initial_bounds.inner_crop(design_bounds)
    layer.opacity = sif_layer_data[:opacity]
    layer.text = sif_layer_data[:text]
    layer.shape = sif_layer_data[:shape]
    layer.styles = sif_layer_data[:styles]
    layer.style_layer = sif_layer_data[:style_layer]
    if not sif_layer_data[:grouping_box].nil?
      layer.grouping_box = BoundingBox.create_from_attribute_data sif_layer_data[:grouping_box]
    end
    layer.design = @design
    return layer
  end

  def create_grouping_box(serialized_data)
    layer_keys = serialized_data[:layers]
    orientation = serialized_data[:orientation]
    bounds = BoundingBox.create_from_attribute_data serialized_data[:bounds]
    has_intersecting_layers = serialized_data.fetch :has_intersecting_layers, false
    alternate_grouping_boxes = serialized_data.fetch :alternate_grouping_boxes, nil
    
    layers = layer_keys.collect do |layer_uid| 
      @layers[layer_uid] 
    end

    grouping_box = GroupingBox.new :layers => layers, :bounds => bounds, :orientation => orientation, :design => @design,
      :has_intersecting_layers => has_intersecting_layers, :alternate_grouping_boxes => alternate_grouping_boxes

    serialized_data[:children].each do |child_data|
      child_grouping_box = self.create_grouping_box child_data
      grouping_box.add child_grouping_box
    end

    grouping_box
  end

  def create_grid(serialized_data)
    layer_keys = serialized_data[:layers]
    style_layer_keys = serialized_data[:style_layers]

    orientation = serialized_data[:orientation]
    style_rules = serialized_data[:style_rules]
    grouping_box = GroupingBox.get_node @root_grouping_box, serialized_data[:grouping_box]

    if not serialized_data[:offset_box].nil?
      offset_box = BoundingBox.create_from_attribute_data serialized_data[:offset_box]
    end

    layers = layer_keys.collect do |layer_uid| 
      @layers[layer_uid] 
    end

    style_layers = style_layer_keys.collect do |style_layer_uid|
      @layers[style_layer_uid]
    end

    grid = Grid.new :layers => layers, 
      :style_layers => style_layers, 
      :offset_box => offset_box, 
      :grouping_box => grouping_box, 
      :orientation => orientation, 
      :style_rules => style_rules,
      :css_class_name => serialized_data[:css_class_name],
      :design => @design

    serialized_data[:children].each do |child_data|
      child_grid = self.create_grid child_data
      grid.add child_grid
    end

    grid
  end
end
