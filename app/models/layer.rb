class Layer
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated
  include ActionView::Helpers::TagHelper

  LAYER_TEXT          = "LayerKind.TEXT"
  LAYER_SMARTOBJECT   = "LayerKind.SMARTOBJECT"
  LAYER_SOLIDFILL     = "LayerKind.SOLIDFILL"
  LAYER_NORMAL        = "LayerKind.NORMAL"
  LAYER_HUESATURATION = "LayerKind.HUESATURATION"
  
  BOUND_MODES = {
    :NORMAL_BOUNDS => :bounds,
    :EDGE_BOUNDS => :edge_detected_bounds, 
    :SNAPPED_BOUNDS => :snapped_bounds
    }

  has_and_belongs_to_many :grids, :class_name => 'Grid'
  belongs_to :design

  field :uid, :type  => String
  field :name, :type => String
  field :kind, :type => String
  field :raw, :type  => String
  field :layer_type, :type => String, :default => nil
  field :is_overlay, :type => Boolean
  
  field :layer_bounds, :type => String, :default => nil

  # Do not store layer_object, but have in memory
  
  attr_accessor :layer_object, :bounds, :intersect_count, :overlays

  def self.create_from_raw_data(layer_json, design_id)
    layer = Layer.new
    design = Design.find design_id
    layer.design = design
    layer.save!
    
    layer.set layer_json
    return layer
  end

  def set(layer)
    self.name       = layer[:name][:value]
    self.kind       = layer[:layerKind]
    self.layer_type = layer[:layerType]
    self.uid        = layer[:layerID][:value]
    self.raw        = layer.to_json.to_s
    
    bounds_key = self.bounds_key
    value  = self.layer_json[bounds_key][:value]
    top    = value[:top][:value]
    bottom = value[:bottom][:value]
    left   = value[:left][:value]
    right  = value[:right][:value]

    design_bounds = BoundingBox.new 0, 0, self.design.height, self.design.width
    layer_bounds  = BoundingBox.new(top, left, bottom, right).inner_crop(design_bounds)
    
    self.layer_bounds = BoundingBox.pickle layer_bounds
    self.save!
  end
  
  def attribute_data
    {
      :uid => self.uid,
      :name => self.name,
      :kind => self.kind,
      :layer_type => self.layer_type
    }
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
    # Store layer object in memory.  
    if not @layer_object
      @layer_object = JSON.parse self.raw, :symbolize_names => true, :max_nesting => false
    end
    
    @layer_object
  end
  
  def bounds_key
    key = BOUND_MODES[@bound_mode]
    key = BOUND_MODES[:NORMAL_BOUNDS] if key.nil?
  end

  def bounds
    BoundingBox.depickle self.layer_bounds
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

  def image_path
    CssParser::get_image_path(self) if self.kind == LAYER_SMARTOBJECT or self.kind == LAYER_NORMAL
  end

  def tag_name(is_leaf = false)
    if self.kind == LAYER_SMARTOBJECT
      if is_leaf
        :img
      else
        :div
      end
    elsif self.kind == LAYER_NORMAL
      if self.renderable_image? and is_leaf
        :img
      else
        :div
      end
    elsif self.kind  == LAYER_TEXT or self.kind == LAYER_SOLIDFILL
      :div
    else
      Log.info "New layer found #{self.kind} for layer #{self.name}"
      :div
    end
  end

  def get_css(css = {}, is_leaf = false, is_root = false, grid = nil)
    if self.kind == LAYER_TEXT
      css.update CssParser::parse_text self
    elsif self.kind == LAYER_SMARTOBJECT
      # don't do anything
    elsif self.kind == LAYER_SOLIDFILL
      css.update CssParser::parse_box self, grid
    end
    
    css.update CssParser::position_absolutely(self, grid) if self.is_overlay?

    if self.kind == LAYER_TEXT
      css.update CssParser::parse_text self
    elsif not is_leaf and (self.kind == LAYER_SMARTOBJECT or renderable_image?)
      #TODO Replace into a css parser function
      css[:background] = "url('../../#{image_path}') no-repeat"
      css[:'background-size'] = "contain"
      css[:width] = "#{self.bounds.width}px"
      css[:height] = "#{self.bounds.height}px"
      # don't do anything
    elsif self.kind == LAYER_SOLIDFILL
      css.update CssParser::parse_box self, grid
      if is_root
        css.delete :width
        css.delete :height
        css.delete :'min-height'
        css[:margin] = "0 auto"
        css[:width] = '960px'
      end
    end
    
    css
  end

  def class_name(css = {}, is_leaf, is_root, grid)
    css = get_css(css, is_leaf, is_root, grid)
    PhotoshopItem::StylesHash.add_and_get_class CssParser::to_style_string(css)
  end

  def get_raw_font_name
    font_name = nil

    if layer_json[:layerKind] == Layer::LAYER_TEXT
      text_style = layer_json[:textKey][:value][:textStyleRange][:value].first
      if not text_style.nil?
        font_info  = text_style[:value][:textStyle][:value]
        font_name  = font_info[:fontName][:value]
      end
    end    
    
    font_name
  end
  
  def get_font_name
    raw_font_name = self.get_raw_font_name
    return nil if raw_font_name.nil?
    
    design = self.grids.first.design
    font_map = design.font_map
    if font_map.has_key? raw_font_name
      font_name = font_name[raw_font_name]
    else
      font_name = raw_font_name
    end
    
    font_name
  end
  
  # A Layer whose bounds are zero
  def empty?
    is_empty = false
    if self.bounds
     is_empty =  ((self.bounds.top + self.bounds.left + self.bounds.bottom + self.bounds.right) == 0)
    end
    
    is_empty
  end
  
  def text
    if self.kind == LAYER_TEXT
      layer_json[:textKey][:value][:textKey][:value]
    else
      ''
    end
  end

  def to_html(args = {}, is_leaf, grid)
    #puts "Generating html for #{self.inspect}"
    css       = args.fetch :css, {}
    css_class = class_name css, is_leaf, @is_root, grid
    
    tag = tag_name(is_leaf)

    inner_html = args.fetch :inner_html, ''
    if inner_html.empty? and self.kind == LAYER_TEXT
      inner_html = text
    end

    attributes         = Hash.new
    css_class_list     = (args.has_key? :class ) ? [args[:class]] : []
    css_class_list.push css_class
    attributes[:class] = css_class_list.join ' '

    attributes[:"data-grid-id"]  = args[:"data-grid-id"] if not args[:"data-grid-id"].nil?
    attributes[:"data-layer-id"] = self.id.to_s

    if tag == :img
      attributes[:src] = image_path
      html = tag "img", attributes
    else
      html = content_tag tag, inner_html, attributes, false
    end

    return html
  end
  
  def styleable_layer?
    (self.kind == Layer::LAYER_SOLIDFILL or
     self.kind == Layer::LAYER_HUESATURATION or
     self.kind == Layer::LAYER_NORMAL or
     self.renderable_image?)
  end

  def to_s
    "#{self.name} - #{self.bounds}"
  end
  
  def inspect
    self.to_s
  end

  def print(indent_level = 0)
    spaces = ""
    prefix = "|--"
    indent_level.times {|i| spaces+=" "}
    Log.debug "#{spaces}#{prefix} (layer) #{self.name} #{@bounds.to_s}"
  end

end
