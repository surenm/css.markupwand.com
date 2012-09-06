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
  attr_accessor :layer_mask
  attr_accessor :num_layers
  attr_accessor :layers
  attr_accessor :design
  
  def self.write(design, sif_data)
    sif_file = File.join design.store_key_prefix, "#{design.safe_name_prefix}.sif"
    Store.write_contents_to_store sif_file, sif_data.to_json
  end
  
  def self.read(design)
  end
  
  def self.update(design, updates)
  end
  
  # SIF is Smart Interface Format
  def initialize(file_path, design)
    raise SifParseError if not File.exists? file_path

    fptr = File.read file_path
    # This is json reference is opened only once,
    # written back only through this.
    # 
    # This is equivalent of a db connection pool -
    # all writes to this file go through this.
    @sif = JSON.parse fptr, :symbolize_names => true, :max_nesting => false

    # Appends design data with design's properties
    @design = design

    self.parse
  end
  
  

  def parse
    begin
      @header = @sif[:header]
      self.validate_header

      @layer_mask = @sif[:layerMask]
      self.validate_layer_mask

      @num_layers = @layer_mask[:numLayers]
      # Set design's properties

      set_design_properties
      create_layers
    rescue Exception => e
      raise e
    end
  end

  def set_design_properties
    @design.height = get_design_height 
    @design.width  = get_design_width
  end

  # Get the layer objects. Right now, fetch from mongo
  # for that design.
  # 
  # Once mongo is removed, create and edit layers 
  # directly from file
  def create_layers
    @layers = []
    @layer_mask[:layers].each do |layer_json|
      layer = Sif::SifLayer::create layer_json, @design
      @layers.push layer
      Log.info "Creating from SIF #{layer.name}"
    end
  end

  # TODO - signature correct, change implementation later
  def get_sif_layer_by_id(layerId)
    @layer_mask[:layers].each do |layer_json|
      if layer_json[:layerId] == layerId
        return layer_json
      end
    end
  end

  def validate_keys_in_hash(obj, keys)
    keys.each do |key|
      raise SifParseError if not obj.has_key? key
    end
  end

  def validate_header
    must_header_keys = [:width, :height, :modename]
    self.validate_keys_in_hash @header, must_header_keys
  end

  def validate_layer_mask
    must_layermask_keys = [:layers, :numLayers]
    self.validate_keys_in_hash @layer_mask, must_layermask_keys
  end

  def get_design_width
    return @header[:width]
  end 
  
  def get_design_height
    return @header[:height]
  end

  def get_layers
    @layers
  end
end
