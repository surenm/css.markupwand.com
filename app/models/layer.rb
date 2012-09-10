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
  LAYER_NORMAL             = "normal"
  LAYER_PATTERNFILL        = "LayerKind.PATTERNFILL"
  LAYER_PHOTOFILTER        = "LayerKind.PHOTOFILTER"
  LAYER_POSTERIZE          = "LayerKind.POSTERIZE"
  LAYER_SELECTIVECOLOR     = "LayerKind.SELECTIVECOLOR"
  LAYER_SMARTOBJECT        = "LayerKind.SMARTOBJECT"
  LAYER_SOLIDFILL          = "LayerKind.SOLIDFILL"
  LAYER_TEXT               = "text"
  LAYER_THRESHOLD          = "LayerKind.THRESHOLD"
  LAYER_LAYER3D            = "LayerKind.LAYER3D"
  LAYER_VIBRANCE           = "LayerKind.VIBRANCE"
  LAYER_VIDEO              = "LayerKind.VIDEO"
  

  ### Relational references ###

  # Belongs to multiple grids
  attr_accessor :grids

  # Belongs to a design
  attr_accessor :design

  # Layer's imported data
  attr_accessor :uid # (String)
  attr_accessor :name # (String)
  attr_accessor :type # (String)
  attr_accessor :zindex # (Integer)
  attr_accessor :opacity #(Integer)
  attr_accessor :bounds #(BoundingBox)
  attr_accessor :smart_bounds #(BoundingBox)

  attr_accessor :text
  attr_accessor :shapes
  attr_accessor :styles

  attr_accessor :is_overlay # (Boolean)
  attr_accessor :is_style_layer # (Boolean)
  attr_accessor :override_tag # (String)

  # CSS Rules
  attr_accessor :computed_css # (Hash)
  attr_reader   :css_rules # (Array)
  attr_accessor :chunk_text_css_rule # (Array)
  attr_accessor :chunk_text_css_selector # (Array)
  attr_accessor :extra_selectors # (Array)
  attr_accessor :generated_selector # (String)

  # Decided that it is not multifont not based on photoshop,
  # but based on the repeating hash values.
  attr_accessor :is_multifont # (Boolean)

  attr_accessor :layer_object, :intersect_count, :overlays, :invalid_layer
    
  def attribute_data
    {
        :uid     => self.uid,
        :name    => self.name,
        :type    => self.type,
        :zindex  => self.zindex,
        :bounds  => self.bounds.attribute_data,
        :opacity => self.opacity,
        :text    => self.text,
        :shapes  => self.shapes,
        :styles  => self.styles,
    }
  end

  def has_multifont?
    multifont = false
    if self.type == Layer::LAYER_TEXT
      # Sum of all positions is > 0
      multifont = (multifont_positions.inject(:+) > 0)
    end

    multifont || self.is_multifont
  end

  def multifont_positions
    positions = []
    if self.type == Layer::LAYER_TEXT
      positions = layer_json.extract_value(:textKey, :value, :textStyleRange, :value).map do |font|
        font.extract_value(:value, :from, :value)
      end
    end

    positions
  end

  def has_newline?
    if self.type == Layer::LAYER_TEXT and
        layer_json.has_key? :textKey and
        layer_json.extract_value(:textKey, :value).has_key? :textKey

      string_data = layer_json[:textKey][:value][:textKey][:value]
      (string_data =~ /\r/) or (string_data =~ /\n/)
    else
      false
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

  def zero_area?
    self.bounds.nil? or self.bounds.area == 0 or self.bounds.area.nil?
  end

  #TODO Requires cleanup
  def image_path
    if not @image_path
      layer_safe_name = Store::get_safe_name(self.name)
      image_base_name = "#{layer_safe_name}_#{self.uid}.png"
      @image_path     = "./assets/images/#{image_base_name}"
      src_image_file  = Rails.root.join("tmp", "store", self.design.store_extracted_key, @image_path).to_s
      generated       = File.join self.design.store_generated_key, "assets", "images", image_base_name
      published       = File.join self.design.store_published_key, "assets", "images", image_base_name
      Store::save_to_store src_image_file, generated
      Store::save_to_store src_image_file, published
    end

    @image_path
  end

  def tag_name(is_leaf = false)
    chosen_tag = ""
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
    elsif self.type == LAYER_TEXT or self.type == LAYER_SOLIDFILL
      chosen_tag = :div
    else
      Log.info "New layer found #{self.type} for layer #{self.name}"
      chosen_tag = :div
    end
    chosen_tag
  end

  # Array of CSS rules, created using 
  # computed using computed css and 
  def css_rules
    computed_css_array  = Compassify::get_scss(self.computed_css)
    generated_css_array = Compassify::get_scss(self.styles)

    generated_css_array + computed_css_array
  end

  def set_style_rules(grid_style)
    is_leaf = grid_style.grid.leaf?

    self.extra_selectors = grid_style.extra_selectors
    
    # Things to do with styles
    # 1. Background image
    # 2. Multifont
    @generated_selector = CssParser::create_incremental_selector
  end

  #FIXME PSDJS
  def chunk_text_rules
    chunk_text_rules = ''
    return chunk_text_rules

    self.chunk_text_css_rule.each_with_index do |value, index|
      if not value.empty?
        rule_list = CssParser::to_style_string(value)
        current_rule =  <<sass
.#{self.chunk_text_css_selector[index]} {
#{rule_list}
}
sass
        chunk_text_rules += current_rule
      end
    end

    chunk_text_rules
  end

  # Finds out if the same style is repeating for multifont,
  # i.e it is not really a multifont, and makes it unique, adds it to computed_css.
  def multifont_style_uniq
    multifont_array = self.chunk_text_css_rule.clone.uniq
    uniqued_multifont_data = {}
    
    if multifont_array.length == 1
      self.chunk_text_css_rule = []
      uniqued_multifont_data = multifont_array.first 
    end

    uniqued_multifont_data
  end

  def is_empty_text_layer?
    if self.type == Layer::LAYER_TEXT
      text_content = layer_json.extract_value(:textKey, :value, :textKey, :value)
      if text_content.length == 0
        return true
      end
    end
    return false
  end

  def modified_generated_selector(grid)
    return self.generated_selector
    modified_selector_name = grid.design.selector_name_map[self.generated_selector]
    if not modified_selector_name.nil?
      modified_selector_name["name"]
    else
      self.generated_selector
    end
  end

  # Selector names (includes default selector and extra selectors)
  def selector_names(grid)
    all_selectors = extra_selectors
    all_selectors.push self.modified_generated_selector(grid)

    all_selectors.uniq!
    all_selectors
  end

  def get_raw_font_name(position = 0)
    font_name = nil

    if self.type == Layer::LAYER_TEXT and not is_empty_text_layer?
      font_name = layer_json.extract_value(:textKey, :value, :textStyleRange, :value)[position].extract_value(:value, :textStyle, :value, :fontName, :value)
    end

    font_name
  end

  def get_font_name(position)
    raw_font_name = self.get_raw_font_name(position)
    return nil if raw_font_name.nil?

    design = self.grids.first.design
    #design.font_map.get_font raw_font_name
    raw_font_name
  end

  # A Layer whose bounds are zero
  def empty?
    is_empty = false
    if self.bounds
      is_empty = ((self.bounds.top + self.bounds.left + self.bounds.bottom + self.bounds.right) == 0)
    end

    is_empty
  end

  def text_type
    if layer_json.has_key? :textType
      return layer_json[:textType]
    else
      return ""
    end
  end

  def text_content
    if self.type == LAYER_TEXT
      original_text = self.text

      #FIXME PSDJS
      if false and has_multifont?
        positions = multifont_positions
        chunks = []
        positions.each_with_index do |position, index|
          if (position == positions[index + 1])
            chunks.push ""
          else
            next_position = (index == positions.length - 1) ? (original_text.length - 1) : (positions[index + 1] - 1)
            chunks.push original_text[position..next_position]
          end
        end

        multifont_text = ''

        chunks.each_with_index do |chunk, index|
          next if chunk.length == 0
          newlined_chunk = ActiveSupport::SafeBuffer.new(chunk.gsub("\n", "<br>").gsub("\r\r", "<br>").gsub("\r", "<br>"))
          attributes = { :class => self.chunk_text_css_selector[index] }
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

  def crop_image(image_file)
    Log.debug "Checking whether to crop #{image_file}"
    if self.bounds == self.initial_bounds
      Log.debug "Decided not to crop"
      return
    end

    Log.debug "Decided that it should be cropped"

    image_name = File.basename image_file

    self.design.fetch_processed_folder

    processed_folder = File.dirname design.processed_file_path
    current_image_path = File.join processed_folder, image_name
    Log.debug "Reading the image #{current_image_path}"
    current_image = Image.read(current_image_path).first

    image_width = current_image.columns
    image_height = current_image.rows

    Log.debug "Checking if the image in disk is bigger than the desired size"

    if image_width >= self.bounds.width and image_height >= self.bounds.height
      Log.debug "Yes it is! Cropping..."

      top_offset = (self.bounds.top - self.initial_bounds.top).abs
      left_offset = (self.bounds.left - self.initial_bounds.left).abs

      Log.info "Cropping #{current_image_path} at offsets - top: #{top_offset} left: #{left_offset}"
      current_image.crop!(left_offset, top_offset, self.bounds.width, self.bounds.height)
      current_image.write(current_image_path)

      Log.debug "Saving to the store"
      Store::save_to_store current_image_path, File.join(design.store_processed_key, image_name)
    elsif  image_width < self.bounds.width and image_height < self.bounds.height
      Log.error "Looks like the image has been cropped to a smaller size than desired."
      return
    else
      Log.info "Looks like someone beat me to cropping it. Not cropping again."
      return
    end
  end

  def crop_objects_for_cropped_bounds
    if self.type == LAYER_NORMAL
      crop_image self.image_path
    end
  end

  def to_html(args = {}, is_leaf, grid)
    Log.info "[HTML] Layer #{self.to_s}"
    
    generated_tag = tag_name(is_leaf)
    tag = args.fetch :tag, generated_tag

    inner_html = args.fetch :inner_html, ''
    if inner_html.empty? and self.type == LAYER_TEXT
      inner_html += self.text_content
    end

    attributes         = Hash.new
    attributes[:"data-grid-id"] = args.fetch :"data-grid-id", ""
    attributes[:"data-layer-id"] = self.uid.to_s
    attributes[:"data-layer-name"] = self.name
    attributes[:class] = self.selector_names(grid).join(" ") if not self.selector_names(grid).empty?

    if tag == :img
      attributes[:src] = self.image_path
      html = tag "img", attributes, false
    else
      html = content_tag tag, inner_html, attributes, false
    end

    return html
  end

  def styleable_layer?
    (self.type != Layer::LAYER_TEXT)
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
