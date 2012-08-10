require 'RMagick'
include Magick

class Layer
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated
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
  LAYER_NORMAL             = "LayerKind.NORMAL"
  LAYER_PATTERNFILL        = "LayerKind.PATTERNFILL"
  LAYER_PHOTOFILTER        = "LayerKind.PHOTOFILTER"
  LAYER_POSTERIZE          = "LayerKind.POSTERIZE"
  LAYER_SELECTIVECOLOR     = "LayerKind.SELECTIVECOLOR"
  LAYER_SMARTOBJECT        = "LayerKind.SMARTOBJECT"
  LAYER_SOLIDFILL          = "LayerKind.SOLIDFILL"
  LAYER_TEXT               = "LayerKind.TEXT"
  LAYER_THRESHOLD          = "LayerKind.THRESHOLD"
  LAYER_LAYER3D            = "LayerKind.LAYER3D"
  LAYER_VIBRANCE           = "LayerKind.VIBRANCE"
  LAYER_VIDEO              = "LayerKind.VIDEO"
  

  BOUND_MODES = {
    :NORMAL_BOUNDS  => :bounds,
    :SMART_BOUNDS   => :smart_bounds,
    :EDGE_BOUNDS    => :edge_detected_bounds,
    :SNAPPED_BOUNDS => :snapped_bounds
  }

  has_and_belongs_to_many :grids, :class_name => 'Grid'
  belongs_to :design

  field :uid, :type => String
  field :name, :type => String
  field :kind, :type => String
  field :raw, :type => String
  field :layer_type, :type => String, :default => nil
  field :is_overlay, :type => Boolean
  field :is_style_layer, :type => Boolean, :default => false

  field :override_tag, :type => String, :default => nil
  field :layer_bounds, :type => String, :default => nil

  # CSS Rules
  field :css_rules, :type => Hash, :default => {}
  field :chunk_text_css_rule, :type => Array, :default => []
  field :chunk_text_css_selector, :type => Array, :default => []
  field :extra_selectors, :type => Array, :default => []
  field :generated_selector, :type => String

  # Decided that it is not multifont not based on photoshop,
  # but based on the repeating hash values.
  field :is_multifont, :type => Boolean, :default => false

  # The bounds of the layer before any changes are made to it.
  # 
  field :initial_layer_bounds, :type => String, :default => nil

  # TOD: Do not store layer_object, but have in memory

  attr_accessor :layer_object, :intersect_count, :overlays, :invalid_layer

  def self.create_from_raw_data(layer_json, design)
    layer = Layer.new
    layer.design = design

    layer.set layer_json
    return layer
  end


  def set(layer)
    self.name = layer[:name][:value]
    self.kind = layer[:layerKind]
    self.layer_type = layer[:layerType]
    self.uid = layer[:layerID][:value]

    if self.layer_json[BOUND_MODES[:SMART_BOUNDS]] and not self.layer_json[BOUND_MODES[:SMART_BOUNDS]].empty?
      self.set_bounds_mode(:SMART_BOUNDS)
    end

    bounds_key = self.bounds_key
    value = self.layer_json[bounds_key][:value]
    top = value[:top][:value]
    bottom = value[:bottom][:value]
    left = value[:left][:value]
    right = value[:right][:value]

    if self.initial_bounds.nil?
      initial_bounds = BoundingBox.new(top, left, bottom, right)
      self.initial_bounds = initial_bounds
    end

    design_bounds = BoundingBox.new 0, 0, self.design.height, self.design.width
    layer_bounds = BoundingBox.new(top, left, bottom, right).inner_crop(design_bounds)

    if layer_bounds.nil?
      self.invalid_layer = true
    else
      self.invalid_layer = false
      self.layer_bounds = BoundingBox.pickle layer_bounds
      self.save!
    end
  end

  # TODO Change object property and initialize when we are making properties inside.
  def zindex
    layer_json.extract_value(:itemIndex, :value)
  end

  def attribute_data
    {
        :uid => self.uid,
        :name => self.name,
        :kind => self.kind,
        :layer_type => self.layer_type,
        :label => self.name[0..9],
        :tag => self.tag_name
    }
  end

  def has_multifont?
    multifont = false
    if self.kind == Layer::LAYER_TEXT
      # Sum of all positions is > 0
      multifont = (multifont_positions.inject(:+) > 0)
    end

    multifont || self.is_multifont
  end

  def multifont_positions
    positions = []
    if self.kind == Layer::LAYER_TEXT
      positions = layer_json.extract_value(:textKey, :value, :textStyleRange, :value).map do |font|
        font.extract_value(:value, :from, :value)
      end
    end

    positions
  end

  def has_newline?
    if self.kind == Layer::LAYER_TEXT and
        layer_json.has_key? :textKey and
        layer_json.extract_value(:textKey, :value).has_key? :textKey

      string_data = layer_json[:textKey][:value][:textKey][:value]
      (string_data =~ /\r/) or (string_data =~ /\n/)
    else
      false
    end
  end

  def set_bounds_mode(bound_mode)
    unless BOUND_MODES.include? bound_mode
      raise "Unknown bound mode #{bound_mode}"
    end
    @bound_mode = bound_mode
  end

  def layer_json
    if not @layer_object
      psd_data = self.design.get_processed_data
      @layer_object = psd_data[:art_layers].fetch :"#{self.uid}"
    end

    @layer_object
  end

  def bounds_key
    key = BOUND_MODES[@bound_mode]
    key = BOUND_MODES[:NORMAL_BOUNDS] if key.nil?

    key
  end

  def bounds
    BoundingBox.depickle self.layer_bounds
  end

  def initial_bounds
    BoundingBox.depickle self.initial_layer_bounds
  end

  def initial_bounds=(new_bound)
    if self.initial_layer_bounds.nil?
      self.initial_layer_bounds = BoundingBox.pickle(new_bound)
    end
  end

  def bounds=(new_bound)
    self.layer_bounds = BoundingBox.pickle(new_bound)
  end

  def <=>(other_layer)
    self.bounds <=> other_layer.bounds
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

  def renderable_image?
    !self.layer_json.nil? and self.layer_json.has_key? :renderImage and self.layer_json[:renderImage]
  end

  def unmaskable_layer?
    self.kind == Layer::LAYER_HUESATURATION
  end

  def zero_area?
    self.bounds.nil? or self.bounds.area == 0 or self.bounds.area.nil?
  end

  def image_path
    CssParser::get_image_path(self) if self.kind == LAYER_SMARTOBJECT or self.kind == LAYER_NORMAL
  end

  def tag_name(is_leaf = false)
    chosen_tag = ""
    if not self.override_tag.nil?
      self.override_tag
    elsif self.kind == LAYER_SMARTOBJECT
      if is_leaf
        chosen_tag = :img
      else
        chosen_tag = :div
      end
    elsif self.kind == LAYER_NORMAL
      if self.renderable_image? and is_leaf
        chosen_tag = :img
      else
        chosen_tag = :div
      end
    elsif self.kind == LAYER_TEXT or self.kind == LAYER_SOLIDFILL
      chosen_tag = :div
    else
      Log.info "New layer found #{self.kind} for layer #{self.name}"
      chosen_tag = :div
    end
    chosen_tag
  end

  def set_style_rules(grid_style_selector)
    crop_objects_for_cropped_bounds
    is_leaf = grid_style_selector.grid.is_leaf?
  
    css = {}
    if not self.is_style_layer and not self.tag_name(is_leaf) == :img
      css.update grid_style_selector.css_rules
    end
  
    self.extra_selectors = grid_style_selector.extra_selectors
    if self.kind == LAYER_TEXT
      css.update CssParser::parse_text self
    elsif not is_leaf and (self.kind == LAYER_SMARTOBJECT or renderable_image?)
      css.update CssParser::parse_background_image(self, grid_style_selector.grid)
    elsif self.kind == LAYER_SOLIDFILL
      css.update CssParser::parse_shape self, grid_style_selector.grid
    end

    if has_multifont?
      positions = multifont_positions
      positions.each_with_index do |position, index|
        self.chunk_text_css_rule[index]     = CssParser::get_text_chunk_style(self, index)
        self.chunk_text_css_selector[index] = CssParser::create_incremental_selector
      end

      css.update multifont_style_uniq
      self.save!
    end

    self.generated_selector = CssParser::create_incremental_selector if not css.empty?
    CssParser::add_to_inverted_properties(css, grid_style_selector.grid)

    self.css_rules = css
    self.save!
  end

  def chunk_text_rules
    chunk_text_rules = ''
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
  # i.e it is not really a multifont, and makes it unique, adds it to css_rules.
  def multifont_style_uniq
    multifont_array = self.chunk_text_css_rule.clone.uniq
    uniqued_multifont_data = {}
    
    if multifont_array.length == 1
      self.chunk_text_css_rule = []
      uniqued_multifont_data = multifont_array.first 
    end

    uniqued_multifont_data
  end

  def get_style_rules(grid_style_selector)
    set_style_rules(grid_style_selector) #if self.css_rules.empty?

    self.css_rules
  end

  def is_empty_text_layer?
    if self.kind == Layer::LAYER_TEXT
      text_content = layer_json.extract_value(:textKey, :value, :textKey, :value)
      if text_content.length == 0
        return true
      end
    end
    return false
  end

  def modified_generated_selector(grid)
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
    if not self.css_rules.empty?
      all_selectors.push self.modified_generated_selector(grid) if not self.css_rules.empty?
    end

    if not grid.style_selector.hashed_selectors.empty?
      all_selectors = all_selectors + grid.style_selector.modified_hashed_selector
    end

    all_selectors.uniq!
    all_selectors
  end

  def get_raw_font_name(position = 0)
    font_name = nil

    if self.kind == Layer::LAYER_TEXT and not is_empty_text_layer?
      font_name = layer_json.extract_value(:textKey, :value, :textStyleRange, :value)[position].extract_value(:value, :textStyle, :value, :fontName, :value)
    end

    font_name
  end

  def get_font_name(position)
    raw_font_name = self.get_raw_font_name(position)
    return nil if raw_font_name.nil?

    design = self.grids.first.design
    design.font_map.get_font raw_font_name
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

  def text
    if self.kind == LAYER_TEXT
      original_text = layer_json[:textKey][:value][:textKey][:value]

      if has_multifont?
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
    if self.renderable_image?
      crop_image image_path
    end
  end

  def to_html(args = {}, is_leaf, grid)
    Log.info "[HTML] Layer #{self.to_s}"
    
    generated_tag = tag_name(is_leaf)
    tag = args.fetch :tag, generated_tag

    inner_html = args.fetch :inner_html, ''
    if inner_html.empty? and self.kind == LAYER_TEXT
      inner_html += text
    end

    attributes         = Hash.new

    attributes[:"data-grid-id"] = args.fetch :"data-grid-id", ""
    attributes[:"data-layer-id"] = self.id.to_s
    attributes[:"data-layer-name"] = self.name
    attributes[:class] = self.selector_names(grid).join(" ") if not self.selector_names(grid).empty?

    if tag == :img
      attributes[:src] = image_path
      html = tag "img", attributes, false
    else
      html = content_tag tag, inner_html, attributes, false
    end

    return html
  end

  def styleable_layer?
    (self.kind != Layer::LAYER_TEXT)
  end

  def to_s
    "#{self.name} - #{self.bounds} - #{self.kind}"
  end

  def inspect
    self.to_s
  end

  def print(indent_level = 0)
    spaces = ""
    prefix = "|--"
    indent_level.times { |i| spaces += " " }
    Log.debug "#{spaces}#{prefix} (layer) #{self.name} #{@bounds.to_s}"
  end

end
