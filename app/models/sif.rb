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
  
  def parse
    begin
      self.parse_header
      self.parse_layers
      self.parse_grids
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
    @serialized_layers = @sif_data[:layers]
    if @serialized_layers.nil?
      # If the layers are nil, then there is nothing to do.
      raise "Layers data is Nil"
    end
    
    @layers = Hash.new
    @serialized_layers.each do |serialized_layer_data|
      layer = Layer.create_from_sif_data serialized_layer_data
      @layers[layer.uid] = layer
    end
  end
  
  def parse_grids
    @serialized_grids = @sif_data[:grids]
    if @serialized_grids.nil?
      # If there are serialized grids then most probably the design is not yet parsed
      @grids = nil
      return
    end
    
    @grids = Hash.new
    @serialized_grids.each do |serialized_grid_data|
      grid = Grid.create_from_sif_data serialized_grid_data
      @grids[grid.id] = grid
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
  end
  
  def save!
    sif_document = {
      :header => @header,
      :layers => @layers.values,
      :grids  => @grids.values,
    }
    
    # TODO: Do validation checks here
    
    Sif.write @design, sif_document
  end
end
