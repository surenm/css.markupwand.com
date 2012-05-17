class PhotoshopItem::Layer
  include ActionView::Helpers::TagHelper

  attr_accessor :bounds, :name, :layer, :kind, :uid, :font_map_ref, :styles_hash_ref
  
  LAYER_TEXT        = "LayerKind.TEXT"
  LAYER_SMARTOBJECT = "LayerKind.SMARTOBJECT"
  LAYER_SOLIDFILL   = "LayerKind.SOLIDFILL"
  LAYER_NORMAL      = "LayerKind.NORMAL"

  def initialize(layer)
    bound_json = layer[:bounds]
    @name   = layer[:name][:value]
    @kind   = layer[:layerKind]
    @uid    = layer[:layerID][:value]

    self.layer  = layer

    value    = bound_json[:value]
    top     = value[:top][:value]
    bottom  = value[:bottom][:value]
    left    = value[:left][:value]
    right   = value[:right][:value]
    @is_root = false

    @bounds = BoundingBox.new(top, left, bottom, right)
  end
  
  def to_s
    @name
  end

  # Sets that it is a root
  def is_a_root_node
    @is_root = true
  end

  def is_not_root_node
    @is_root = false
  end

  def <=> (other_layer)
    self.bounds <=> other_layer.bounds
  end

  def == (other_layer)
    return false if other_layer == nil
    return (
    self.bounds == other_layer.bounds and
    self.name == other_layer.name and
    self.children == other_layer.children
    )
  end

  # TODO: This is a hard limit encloses function.
  # This actually has to be something like if the areas intersect for more than 50% or so
  # then the bigger one encloses the smaller one.
  def encloses?(other_layer)
    return self.bounds.encloses? other_layer.bounds
  end

  def intersect?(other)
    return self.bounds.intersect? other.bounds
  end
  
  def is_non_smart_image?
    return !self.layer[:layerType].nil? && self.layer[:layerType]=='IMAGE' 
  end 

  def image_path
    if @kind == LAYER_SMARTOBJECT
      CssParser::get_image_path self
    elsif @kind == LAYER_NORMAL
      if self.is_non_smart_image?
        return self.layer[:imagePath]
      else
        nil
      end
    end
  end

  def tag
    if @is_root
      :body
    elsif @kind == LAYER_SMARTOBJECT
      :img
    elsif @kind == LAYER_NORMAL
      if self.is_non_smart_image?
        :img
      else
        :div
      end
    elsif @kind  == LAYER_TEXT or @kind == LAYER_SOLIDFILL
      :div
    else
      Log.info "New layer found #{@kind} for layer #{self.name}"
      :div
    end
  end

  def get_css(css = {}, is_root = false)
    if @kind == LAYER_TEXT
      css.update CssParser::parse_text self.layer, @font_map_ref
    elsif @kind == LAYER_SMARTOBJECT
      # don't do anything
    elsif @kind == LAYER_SOLIDFILL
      css.update CssParser::parse_box self.layer
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

  def class_name(css = {}, is_root = false)
    css = get_css(css, is_root)
    @styles_hash_ref.add_and_get_class(CssParser::to_style_string(css))
  end

  def text
    if @kind == LAYER_TEXT
      self.layer[:textKey][:value][:textKey][:value]
    else
      ''
    end
  end

  def to_html(args = {})
    #puts "Generating html for #{self.inspect}"
    css = args.fetch :css, {}
    @styles_hash_ref = args[:styles_hash]
    @font_map_ref    = args[:font_map]
    css_class        = class_name css, @is_root
    
    inner_html = args.fetch :inner_html, ''
    if inner_html.empty? and @kind == LAYER_TEXT
      inner_html = text
    end
    
    attributes = Hash.new
    attributes[:class] = css_class

    if tag == :img
      html = "<img src='#{image_path}'/>"
    else
      html = content_tag tag, inner_html, attributes, false
    end
    
    return html
  end
  
  def print(indent_level = 0)
    spaces = ""
    prefix = "|--"
    indent_level.times {|i| spaces+=" "}
    puts "#{spaces}#{prefix} (layer) #{@name} #{@bounds.to_s}"
  end
  
end
