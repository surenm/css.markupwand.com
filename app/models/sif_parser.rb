# This should be moved to somewhere
# equivalent of SIF Root - which holds the reference for the file.
#
# 
class SifParser
  class SifParseError < Exception
=begin
    TODO: Parse error could happen when there is unexpected data structure, missing key etc.
    So raise appropriate errors when that happens

=end
  end
  
  # SIF is Smart Interface Format
  def initialize(file_path)
    raise SifParseError if not File.exists? file_path

    fptr = File.read file_path
    # This is json reference is opened only once,
    # written back only through this.
    # 
    # This is equivalent of a db connection pool -
    # all writes to this file go through this.
    @sif = JSON.parse fptr, :symbolize_names => true, :max_nesting => false

    self.parse()
  end

  def parse
    begin
      @header = @sif[:header]
      self.validate_header

      @layer_mask = @sif[:layerMask]
      self.validate_layer_mask

      @num_layers = @layer_mask[:numLayers]
    rescue Exception => e
      raise e
    end
  end

  # Get the layer objects. Right now, fetch from mongo
  # for that design.
  # TODO Mongo remove
  # Once mongo is removed, create and edit layers 
  # directly from file.
  def get_sif_layers(design)
    if @layers.nil?
      @layers = []
      @layer_mask[:layers].each do |layer_json|
        layer = (design.layers.where :uid => layer_json[:layerId]).first
        layer.append_sif_data layer_json
        @layers.push layer
      end
    end

    @layers
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
