class Layer
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated
  include ActionView::Helpers::TagHelper

  LAYER_TEXT        = "LayerKind.TEXT"
  LAYER_SMARTOBJECT = "LayerKind.SMARTOBJECT"
  LAYER_SOLIDFILL   = "LayerKind.SOLIDFILL"
  LAYER_NORMAL      = "LayerKind.NORMAL"

  belongs_to :grid

  field :uid, :type  => String
  field :name, :type => String
  field :kind, :type => String
  field :raw, :type  => String
  field :layer_type, :type => String, :default => nil

  def set(layer)
    self.name       = layer[:name][:value]
    self.kind       = layer[:layerKind]
    self.layer_type = layer[:layerType]
    self.uid        = layer[:layerID][:value]
    self.raw        = layer.to_json.to_s
    self.save!
  end

  def inspect
    "Layer: #{self.name}"
  end

  def layer_json
    JSON.parse self.raw, :symbolize_names => true, :max_nesting => false
  end

  def bounds
    value  = layer_json[:bounds][:value]
    top    = value[:top][:value]
    bottom = value[:bottom][:value]
    left   = value[:left][:value]
    right  = value[:right][:value]

    @bounds = BoundingBox.new(top, left, bottom, right).crop_to(PageGlobals.instance.page_bounds)
  end

  def <=>(other_layer)
    self.bounds <=> other_layer.bounds
  end

  def == (other_layer)
    return false if other_layer == nil
    return (
    self.bounds == other_layer.bounds and
    self.name == other_layer.name
    )
  end

  def encloses?(other_layer)
    return self.bounds.encloses? other_layer.bounds
  end

  def intersect?(other)
    return self.bounds.intersect? other.bounds
  end

  def is_non_smart_image?
    self.layer_type == 'IMAGE'
  end

  def image_path

    if self.kind == LAYER_SMARTOBJECT
      CssParser::get_image_path self
    elsif self.kind == LAYER_NORMAL
      if self.is_non_smart_image?
        return layer_json[:imagePath]
      else
        nil
      end
    end
  end

  def tag(is_leaf = false)
#    debugger
    if self.kind == LAYER_SMARTOBJECT
      if is_leaf
        :img
      else
        :div
      end
    elsif self.kind == LAYER_NORMAL
      if self.is_non_smart_image? and is_leaf
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

  def get_css(css = {}, is_leaf = false, is_root = false)
#    debugger
    if @kind == LAYER_TEXT
      css.update CssParser::parse_text layer_json
    elsif @kind == LAYER_SMARTOBJECT
      # don't do anything
    elsif @kind == LAYER_SOLIDFILL
      css.update CssParser::parse_box layer_json
    end

    if self.kind == LAYER_TEXT
      css.update CssParser::parse_text layer_json
    elsif self.kind == LAYER_SMARTOBJECT
      if not is_leaf
        css[:background] = "url('../../#{image_path}') no-repeat"
        css[:'background-size'] = "contain"
        css[:width] = "#{self.bounds.width}px"
        css[:height] = "#{self.bounds.height}px"
      end
      # don't do anything
    elsif self.kind == LAYER_SOLIDFILL
      css.update CssParser::parse_box layer_json
      if is_root
        css.delete :width
        css.delete :height
        css.delete :'min-height'
        css[:margin] = "0 auto"
        css[:width] = '960px'
      end
    end
#    debugger
    css
  end

  def class_name(css = {}, is_leaf = false, is_root = false)
    css = get_css(css, is_leaf, is_root)
    PhotoshopItem::StylesHash.add_and_get_class CssParser::to_style_string(css)
  end

  def text
    if self.kind == LAYER_TEXT
      layer_json[:textKey][:value][:textKey][:value]
    else
      ''
    end
  end

  def to_html(args = {}, is_leaf)
    #puts "Generating html for #{self.inspect}"
    css       = args.fetch :css, {}
    css_class = class_name css, @is_root

    inner_html = args.fetch :inner_html, ''
    if inner_html.empty? and self.kind == LAYER_TEXT
      inner_html = text
    end

    attributes = Hash.new
    attributes[:class] = css_class

    if tag(is_leaf) == :img
      html = "<img src='#{image_path}'/>"
    else
      html = content_tag tag, inner_html, attributes, false
    end
    return html
  end

  def to_s
    "#{self.name} - #{self.bounds}"
  end

  def print(indent_level = 0)
    spaces = ""
    prefix = "|--"
    indent_level.times {|i| spaces+=" "}
    Log.debug "#{spaces}#{prefix} (layer) #{self.name} #{@bounds.to_s}"
  end

end
