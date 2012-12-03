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

  # Belongs to multiple grids
  attr_accessor :parent_grid #(Grid object)

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
  attr_accessor :smart_bounds #(BoundingBox)
  attr_accessor :tag_name # (Symbol)

  attr_accessor :text
  attr_accessor :shape
  attr_accessor :styles

  attr_accessor :overlay # (Boolean)
  attr_accessor :style_layer # (Boolean)
  attr_accessor :override_tag # (String)

  # CSS Rules
  attr_accessor :computed_css # (Hash)
  attr_reader   :css_rules # (Array)
  attr_accessor :chunk_text_selector # (Array)
  attr_accessor :extra_selectors # (Array)
  attr_accessor :generated_selector # (String)

  attr_accessor :layer_object, :intersect_count, :overlays, :invalid_layer
  
  ##########################################################
  # Layer initialize and serialize functions
  ##########################################################
  def initialize
    @chunk_text_selector = []
  end

  def attribute_data
    parent_grid = self.parent_grid.nil? ? nil : self.parent_grid.id  

    attr_data = {
      :uid     => self.uid,
      :name    => self.name,
      :type    => self.type,
      :zindex  => self.zindex,
      :initial_bounds => self.initial_bounds.attribute_data,
      :bounds  => self.bounds.attribute_data,
      :opacity => self.opacity,
      :text    => self.text,
      :shape   => self.shape,
      :styles  => self.styles,
      :tag     => self.tag_name,
      :design  => self.design.id,
      :overlay => self.overlay,
      :style_layer        => self.style_layer,
      :generated_selector => self.generated_selector,
      :parent_grid        => parent_grid
    }
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
  
  def render_layer?
    self.parent_grid.is_leaf?
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

  def has_multifont?
    self.type == Layer::LAYER_TEXT and self.text_chunks.size > 0
  end

  def text_content
    if self.type == LAYER_TEXT
      original_text = self.full_text

      if has_multifont?

        multifont_text = ''

        self.text_chunks.each_with_index do |chunk, index|
          newlined_chunk = ActiveSupport::SafeBuffer.new(chunk[:text].gsub("\n", "<br>").gsub("\r\r", "<br>").gsub("\r", "<br>"))
          attributes = { :class => self.chunk_text_selector[index] }
          multifont_text +=  content_tag :span, newlined_chunk, attributes
        end

        multifont_text
      else
        original_text
      end
    else
      ''
    end
  end

  ##########################################################
  # Normal Layer helper functions
  ########################################################## 
  
  def image_name
    layer_safe_name = Store::get_safe_name(self.name)
    image_base_name = "#{layer_safe_name.downcase}_#{self.uid}.png"
    return image_base_name
  end

  #TODO Requires cleanup
  def image_path
    if not @image_path
      @image_path     = "./assets/images/#{image_name}"
      src_image_file  = Rails.root.join("tmp", "store", self.design.store_extracted_key, @image_path).to_s
      
      # TODO: this is a temp fix so that parsing goes though instead of breaking!
      if File.exists? src_image_file
        generated       = File.join self.design.store_generated_key, "assets", "images", image_name
        published       = File.join self.design.store_published_key, "assets", "images", image_name
        Store::save_to_store src_image_file, generated
        Store::save_to_store src_image_file, published
      end
    end

    @image_path
  end

  def extracted_image_path
    extracted_folder = Store::fetch_extracted_folder self.design
    Log.debug extracted_folder
    Log.debug image_asset_path
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

    computed_style_rules = Hash.new
    if not self.parent_grid.is_leaf? and self.type == Layer::LAYER_NORMAL
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

  # Selector names (includes default selector and extra selectors)
  def selector_names
    all_selectors = self.extra_selectors
    all_selectors.push self.generated_selector

    if @tag_name != 'img'
      if not self.parent_grid.nil?
        all_selectors.concat parent_grid.style.extra_selectors
      end
    end

    all_selectors.uniq!
    all_selectors
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

  def get_style_node
    if self.type == Layer::LAYER_TEXT
      chunk_nodes = []
      
      chunk_text_selector.each_with_index do |class_name, index|
        chunk_styles = []
        self.text_chunks[index][:styles].each do |rule_key, rule_object|
          if self.allow_chunk_styles? rule_key
            chunk_styles.concat Compassify::get_scss(rule_key, rule_object)
          end
        end
        
        chunk_nodes.push StyleNode.new :class => class_name, :style_rules => chunk_styles
      end
      
      layer_style_node = StyleNode.new :class => self.generated_selector, :style_rules => self.css_rules, :children => chunk_nodes
    else
      layer_style_node = StyleNode.new :class => self.generated_selector, :style_rules => self.css_rules
    end

    return layer_style_node
  end

  def to_scss
    self.get_style_node.to_scss
  end

  ##########################################################
  # HTML generation related functions
  ##########################################################

  def tag_name
    chosen_tag = ""
    is_leaf = (not self.parent_grid.nil?) and self.parent_grid.is_leaf?
      
    if not self.override_tag.nil?
      self.override_tag
    elsif self.type == Layer::LAYER_NORMAL
      if is_leaf
        chosen_tag = 'img'
      else
        chosen_tag = 'div'
      end
    elsif self.type == LAYER_TEXT or self.type == LAYER_SHAPE
      chosen_tag = 'div'
    else
      Log.info "New layer found #{self.type} for layer #{self.name}"
      chosen_tag = 'div'
    end
    @tag_name = chosen_tag
    @tag_name
  end

  def to_html(args = {})
    Log.info "[HTML] Layer #{self.to_s}"
    
    generated_tag = self.tag_name
    @tag_name = args.fetch :tag, generated_tag

    inner_html = args.fetch :inner_html, ''
    if inner_html.empty? and self.type == LAYER_TEXT
      inner_html += self.text_content
    end

    attributes                     = Hash.new
    attributes[:"data-grid-id"]    = args.fetch :"data-grid-id", ""
    attributes[:"data-layer-id"]   = self.uid.to_s
    attributes[:"data-layer-name"] = self.name
    
    if @tag_name == "img"
      attributes[:src] = self.image_path
      html = tag "img", attributes, false
    else
      html = content_tag @tag_name, inner_html, attributes, false
    end

    return html
  end

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
