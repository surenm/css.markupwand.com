class SifParser
  class SifParseError < Exception
  end
  
  # SIF is Smart Interface Format
  def initialize(file_path)
    raise SifParseError if not File.exists? file_path

    fptr = File.read file_path
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
      @layers = @layer_mask[:layers]
    rescue Exception => e
      raise e
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
