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

  # Decided that it is not multifont not based on photoshop,
  # but based on the repeating hash values.
  attr_accessor :is_multifont # (Boolean)

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
    when LAYER_TEXT
      'text'
    when LAYER_NORMAL
      'image'
    when LAYER_SHAPE
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

  def unmaskable_layer?
    self.type == Layer::LAYER_HUESATURATION
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
    return self.full_text.size > 0
  end

  def has_multifont?
    self.type == Layer::LAYER_TEXT and self.text_chunks.size > 0
  end

  def chunk_text_styles
    chunk_text_styles = ""
    chunk_text_selector.each_with_index do |class_name, index|
      rules_array = []
      self.text_chunks[index][:styles].each do |rule_key, rule_object|
        rules_array.concat Compassify::get_scss(rule_key, rule_object)
      end
        
      chunk_text_style =  Utils::build_stylesheet_block class_name, rules_array
      chunk_text_styles += chunk_text_style
    end
    chunk_text_styles
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
      generated       = File.join self.design.store_generated_key, "assets", "images", image_name
      published       = File.join self.design.store_published_key, "assets", "images", image_name
      Store::save_to_store src_image_file, generated
      Store::save_to_store src_image_file, published
    end

    @image_path
  end

  def text_type
    if layer_json.has_key? :textType
      return layer_json[:textType]
    else
      return ""
    end
  end

  def extracted_image_path
    extracted_folder = Store::fetch_extracted_folder self.design
    current_image_path = File.join extracted_folder, image_asset_path
  end

  def image_asset_path
    image_file = File.join "assets", "images", self.image_name
  end

  def crop_image(image_file)
    Log.info "Checking whether to crop #{image_file}"
    if self.bounds == self.initial_bounds
      Log.info "Decided not to crop"
      return
    end

    Log.info "Decided that it should be cropped"

    current_image_path = image_file
    Log.info "Reading the image #{current_image_path}"
    current_image = Image.read(current_image_path).first

    image_width = current_image.columns
    image_height = current_image.rows

    Log.info "Checking if the image in disk is bigger than the desired size"

    if image_width >= self.bounds.width and image_height >= self.bounds.height
      Log.info "Yes it is! Cropping..."

      top_offset = (self.bounds.top - self.initial_bounds.top).abs
      left_offset = (self.bounds.left - self.initial_bounds.left).abs

      Log.info "Cropping #{current_image_path} at offsets - top: #{top_offset} left: #{left_offset}"
      current_image.crop!(left_offset, top_offset, self.bounds.width, self.bounds.height)
      current_image.write(current_image_path)

      Log.info "Saving to the store at - #{File.join(design.store_extracted_key, image_file)}"
      return current_image
    elsif  image_width < self.bounds.width and image_height < self.bounds.height
      Log.info "Looks like the image has been cropped to a smaller size than desired."
      return
    else
      Log.info "Looks like someone beat me to cropping it. Not cropping again."
      return
    end
  end

  def crop_objects_for_cropped_bounds
    if self.type == LAYER_NORMAL
      cropped_image = crop_image self.extracted_image_path
      if not cropped_image.nil?
        Store::save_to_store self.extracted_image_path, File.join(design.store_extracted_key, self.image_asset_path)
      end
    end
  end

  ##########################################################
  # Layer styles related functions
  ##########################################################

  # Array of CSS rules, created using 
  # computed using computed css and 
  def css_rules
    computed_css_array  = []
    generated_css_array = []

    self.computed_css.each do |rule_key, rule_object|
      computed_css_array.concat Compassify::get_scss(rule_key, rule_object)
    end

    generated_css_array = StylesGenerator.get_styles self

    generated_css_array + computed_css_array
  end

  def set_style_rules
    crop_objects_for_cropped_bounds
    grid_style = self.parent_grid.style
    is_leaf    = grid_style.grid.leaf?

    self.extra_selectors = grid_style.extra_selectors
    
    if not is_leaf and self.type == LAYER_NORMAL
      @computed_css[:background]        = "url('../../#{self.image_path}') no-repeat"
      @computed_css[:'background-size'] = "100% 100%"
      @computed_css[:'background-repeat'] = "no-repeat"

      if grid_style
        @computed_css[:'min-width']  = "#{grid_style.unpadded_width}px"
        @computed_css[:'min-height'] = "#{grid_style.unpadded_height}px"
      end
    end

    if is_leaf and self.type == LAYER_SHAPE and grid_style
      @computed_css[:'min-width']  = "#{grid_style.unpadded_width}px"
      @computed_css[:'min-height'] = "#{grid_style.unpadded_height}px"
    end

    
    if not self.text.nil?
      self.text_chunks.each_with_index do |_, index|
        chunk_text_selector[index] = CssParser::create_incremental_selector('text')
      end
    end 
    
    if not self.style_layer and self.generated_selector.nil?
      @generated_selector = CssParser::create_incremental_selector(self.readable_layer_type)
    end

  end

  # Selector names (includes default selector and extra selectors)
  def selector_names(grid)
    all_selectors = self.extra_selectors
    all_selectors.push self.generated_selector

    if @tag_name != :img
      all_selectors.concat grid.style.selector_names
    end

    all_selectors.uniq!
    all_selectors
  end

  def get_raw_font_name(position = 0)
    font_name = nil

    if self.type == Layer::LAYER_TEXT and not is_empty_text_layer?
      font_name = self.text.first[:styles][:'font-family'] unless self.text.first[:styles].nil?
    end

    font_name
  end

  def to_scss
    if self.type == Layer::LAYER_TEXT
      sass = self.chunk_text_styles
    else
      sass = Utils::build_stylesheet_block(self.generated_selector, self.css_rules)
    end
    sass
  end

  ##########################################################
  # HTML generation related functions
  ##########################################################

  def tag_name(is_leaf = false)
    chosen_tag = ""
    if not @tag_name.nil?
      @tag_name
    else
      if not self.override_tag.nil?
        self.override_tag
      elsif self.type == LAYER_SMARTOBJECT
        if is_leaf
          chosen_tag = :img
        else
          chosen_tag = :div
        end
      elsif self.type == LAYER_NORMAL
        if is_leaf
          chosen_tag = :img
        else
          chosen_tag = :div
        end
      elsif self.type == LAYER_TEXT or self.type == LAYER_SHAPE
        chosen_tag = :div
      else
        Log.info "New layer found #{self.type} for layer #{self.name}"
        chosen_tag = :div
      end
      @tag_name = chosen_tag
      @tag_name
    end
  end


  def to_html(args = {}, is_leaf, grid)
    Log.info "[HTML] Layer #{self.to_s}"
    
    generated_tag = tag_name(is_leaf)
    @tag_name = args.fetch :tag, generated_tag

    inner_html = args.fetch :inner_html, ''
    if inner_html.empty? and self.type == LAYER_TEXT
      inner_html += self.text_content
    end

    attributes                     = Hash.new
    attributes[:"data-grid-id"]    = args.fetch :"data-grid-id", ""
    attributes[:"data-layer-id"]   = self.uid.to_s
    attributes[:"data-layer-name"] = self.name
    attributes[:class] = self.selector_names(grid).join(" ") if not self.selector_names(grid).empty?

    if @tag_name == :img
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
