require 'RMagick'
include Magick

class Layer  
  include ActionView::Helpers::TagHelper

  LAYER_BLACKANDWHITE      = "LayerKind.BLACKANDWHITE"
  LAYER_BRIGHTNESSCONTRAST = "LayerKind.BRIGHTNESSCONTRAST"
  LAYER_CHANNELMIXER       = "LayerKind.CHANNELMIXER"
  LAYER_COLORBALANCE       = "LayerKind.COLORBALANCE"
  LAYER_CURVES             = "LayerKind.CURVES"
  LAYER_EXPOSURE           = "LayerKind.EXPOSURE"
  LAYER_GRADIENTFILL       = "LayerKind.GRADIENTFILL"
  LAYER_GRADIENTMAP        = "LayerKind.GRADIENTMAP"
  LAYER_HUESATURATION      = "LayerKind.HUESATURATION"
  LAYER_INVERSION          = "LayerKind.INVERSION"
  LAYER_LEVELS             = "LayerKind.LEVELS"
  LAYER_PATTERNFILL        = "LayerKind.PATTERNFILL"
  LAYER_PHOTOFILTER        = "LayerKind.PHOTOFILTER"
  LAYER_POSTERIZE          = "LayerKind.POSTERIZE"
  LAYER_SELECTIVECOLOR     = "LayerKind.SELECTIVECOLOR"
  LAYER_SMARTOBJECT        = "LayerKind.SMARTOBJECT"
  LAYER_SOLIDFILL          = "LayerKind.SOLIDFILL"
  LAYER_THRESHOLD          = "LayerKind.THRESHOLD"
  LAYER_LAYER3D            = "LayerKind.LAYER3D"
  LAYER_VIBRANCE           = "LayerKind.VIBRANCE"
  LAYER_VIDEO              = "LayerKind.VIDEO"

  # PSDJS layer types
  LAYER_TEXT               = "text"
  LAYER_SHAPE              = "shape" 
  LAYER_NORMAL             = "normal"
 

  ### Relational references ###
  # Belongs to a design
  attr_accessor :design

  # Layer's imported data
  attr_accessor :uid # (String)
  attr_accessor :name # (String)
  attr_accessor :type # (String)
  attr_accessor :zindex # (Integer)
  attr_accessor :opacity #(Integer)
  attr_accessor :initial_bounds #(BoundingBox)
  attr_accessor :bounds #(BoundingBox)

  attr_accessor :text
  attr_accessor :shape
  attr_accessor :styles

  attr_accessor :style_layer # (Boolean)
  
  ##########################################################
  # Layer initialize and serialize functions
  ##########################################################
  def initialize
  end

  def attribute_data
    attr_data = {
      :uid     => self.uid,
      :id      => self.uid,
      :name    => self.name,
      :type    => self.type,
      :zindex  => self.zindex,
      :initial_bounds => self.initial_bounds.attribute_data,
      :bounds  => self.bounds.attribute_data,
      :opacity => self.opacity,
      :text    => self.text,
      :shape   => self.shape,
      :styles  => self.styles,
      :design  => self.design.id,
      :style_layer => self.style_layer,
    }

    if self.type == Layer::LAYER_NORMAL
      attr_data[:image_name] = self.image_name
    end

    return Utils::prune_null_items attr_data
  end
  
  ##########################################################
  # Layer helper functions
  ########################################################## 
  def readable_layer_type
    case self.type
    when Layer::LAYER_TEXT
      'text'
    when Layer::LAYER_NORMAL
      'image'
    when Layer::LAYER_SHAPE
      'rectangle'
    end
  end

  def == (other_layer)
    return false if other_layer.nil?
    return (self.bounds == other_layer.bounds and self.name == other_layer.name)
  end

  def encloses?(other_layer)
    return self.bounds.encloses? other_layer.bounds
  end

  def intersect?(other)
    return self.bounds.intersect? other.bounds
  end

  def intersect_area(other)
    return self.bounds.intersect_area other.bounds
  end

  def eclipses?(other_layer)
    self.encloses? other_layer and self.zindex > other_layer.zindex
  end

  def zero_area?
    self.bounds.nil? or self.bounds.area == 0 or self.bounds.area.nil?
  end

  # A Layer whose bounds are zero
  def empty?
    is_empty = false
    if self.bounds
      is_empty = ((self.bounds.top + self.bounds.left + self.bounds.bottom + self.bounds.right) == 0)
    end

    is_empty
  end

  def styleable_layer?
    (self.type != Layer::LAYER_TEXT)
  end  

  ##########################################################
  # Text Layer helper functions
  ##########################################################

  def full_text
    return self.text[:full_text]
  end

  def text_chunks
    return self.text[:chunks]
  end

  def is_empty_text_layer?
    return self.full_text.size == 0
  end

  ##########################################################
  # Normal Layer helper functions
  ########################################################## 
  
  def image_name
    "#{self.uid}.png"
  end

  def copy_layer_image_to_store
    image_path = "./assets/images/#{self.image_name}"
    src_image_file = Rails.root.join("tmp", "store", self.design.store_extracted_key, image_path).to_s
    Log.fatal src_image_file
    if File.exists? src_image_file
      generated       = File.join self.design.store_generated_key, "assets", "images", self.image_name
      published       = File.join self.design.store_published_key, "assets", "images", self.image_name
      Store::save_to_store src_image_file, generated
      Store::save_to_store src_image_file, published
    else
      Log.fatal "#{src_image_file} Missing"
    end
  end

  #TODO Requires cleanup
  def image_path
    if not @image_path
      @image_path     = "./assets/images/#{image_name}"
    end

    @image_path
  end

  def extracted_image_path
    extracted_folder = Store::fetch_extracted_folder self.design
    current_image_path = File.join extracted_folder, image_asset_path
  end

  def image_asset_path
    image_file = File.join "assets", "images", self.image_name
  end

  def crop_image(image_file)
    Log.debug "Checking whether to crop #{image_file}"
    if self.bounds == self.initial_bounds
      Log.debug "Decided not to crop"
      return
    end

    Log.debug "Decided that it should be cropped"

    current_image_path = image_file
    Log.debug  "Reading the image #{current_image_path}"
    current_image = Image.read(current_image_path).first

    image_width = current_image.columns
    image_height = current_image.rows

    Log.debug "Checking if the image in disk is bigger than the desired size"

    if image_width >= self.bounds.width and image_height >= self.bounds.height
      Log.debug "Yes it is! Cropping..."

      top_offset = (self.bounds.top - self.initial_bounds.top).abs
      left_offset = (self.bounds.left - self.initial_bounds.left).abs

      Log.debug "Cropping #{current_image_path} at offsets - top: #{top_offset} left: #{left_offset}"
      current_image.crop!(left_offset, top_offset, self.bounds.width, self.bounds.height)
      current_image.write(current_image_path)

      Log.debug "Saving to the store at - #{File.join(design.store_extracted_key, self.image_asset_path)}"
      return current_image
    elsif  image_width < self.bounds.width and image_height < self.bounds.height
      Log.debug "Looks like the image has been cropped to a smaller size than desired."
      return
    else
      Log.debug "Looks like someone beat me to cropping it. Not cropping again."
      return
    end
  end

  def crop_objects_for_cropped_bounds
    if self.type == LAYER_NORMAL
      cropped_image = crop_image self.extracted_image_path
      if not cropped_image.nil?
        Log.debug "Cropped image - #{cropped_image}"
        Store::save_to_store self.extracted_image_path, File.join(design.store_extracted_key, self.image_asset_path)
      end
    end
  end

  ##########################################################
  # Layer styles related functions
  ##########################################################

  def get_style_rules
    self.crop_objects_for_cropped_bounds

    if self.type == Layer::LAYER_NORMAL
      self.copy_layer_image_to_store
    end

    computed_style_rules = Hash.new
    if self.style_layer and self.type == Layer::LAYER_NORMAL
      # this means its a style layer and it has image to be set as background  
      computed_style_rules[:background] = "url('../../#{self.image_path}') no-repeat"
      computed_style_rules[:'background-size'] = "100% 100%"
      computed_style_rules[:'background-repeat'] = "no-repeat"
    end

    style_rules = Array.new

    # Get the computed styles for background image for NORMAL layer
    style_rules += Compassify::styles_hash_to_array computed_style_rules

    # Get all the other css3 styles for the layer
    style_rules += StylesGenerator.get_styles self

    return style_rules
  end

  def get_raw_font_name(position = 0)
    font_name = nil

    fonts = []

    if self.type == Layer::LAYER_TEXT and not is_empty_text_layer?
      fonts = self.text[:chunks].collect { |c| c[:styles][:'font-family']} unless self.text[:chunks].nil?
    end

    fonts.uniq
  end
  
  def allow_chunk_styles?(css_property)
    non_allowable_properties = [:color]
    overriding_properties = [:solid_overlay, :gradient_overlay]
    if non_allowable_properties.include? css_property
      overriding_properties.each do |override|
        return false if self.styles.has_key? override
      end
    end
    return true
  end

  ##########################################################
  # DEBUG HELPERS
  ##########################################################
  def to_s
    "#{self.name} - #{self.bounds} - #{self.type}"
  end

  def inspect
    self.to_s
  end

  def print(indent_level = 0)
    spaces = ""
    prefix = "|--"
    indent_level.times { |i| spaces += " " }
    Log.info "#{spaces}#{prefix} (layer) #{self.name} #{@bounds.to_s}"
  end

end
