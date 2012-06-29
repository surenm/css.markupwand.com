class GridStyleSelector
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated  
  include ActionView::Helpers::TagHelper

  embedded_in :grid

  field :css_rules, :type => Hash, :default => {}

  ## Spacing and padding related methods
   
  # Find out bounding box difference from it and its children.
  def padding_from_child
    non_style_layers = self.layers.to_a.select do |layer|
      not self.style_layers.to_a.include? layer.id.to_s
    end
    
    children_bounds = non_style_layers.collect { |layer| layer.bounds }
    children_superbound = BoundingBox.get_super_bounds children_bounds
    spacing = { :top => 0, :left => 0, :bottom => 0, :right => 0 }
    
    if not bounds.nil? and not children_superbound.nil?
      spacing[:top]     = (children_superbound.top  - bounds.top)
      spacing[:bottom]  = (bounds.bottom - children_superbound.bottom)
      
      # Root elements are aligned using 960px, auto. Do not modify anything around them.
      spacing[:left]  = (children_superbound.left - bounds.left) if not self.root
      spacing[:right] = (bounds.right - children_superbound.right ) if not self.root
    end
    spacing
  end
  
  # Spacing includes margin and padding.
  # Margin  = separate the block from things outside it
  # Padding = to move the contents away from the edges of the block.
  # 
  # There are two sources of spacing. 
  #  1. One is offset box (the empty sibling grid that offsets this box)
  #    a) This is always margin, never padding.
  #  2. Another is bounding box difference from its parent grid
  #    a) If it has a single child, calculate the bounding difference from
  #       child and add as padding.
  #    b) If it *is* a single child, do not accept bounding box difference,
  #       it would have got spacing from parent as padding.
  #    c) If it has more than one sibling, calculate relative margin. Absolute
  #       margin (term-invented-by-me) is distance top and left distance from 
  #       bounding box. Relative margin is the distance from it's sibling   
  #       (considering width and margins of its siblings.)
  #
  #    2(b) and 2(c) are exclusive
  def spacing_css
    #TODO. Margin and padding are not always from
    # left and top. It is from all sides.
    margin  = offset_box_spacing
    padding = padding_from_child
    css     = {}
    positions = [:top, :left, :bottom, :right]
    
    positions.each do |position|
      if margin.has_key? position
        css["margin-#{position}".to_sym] = "#{margin[position]}px" if margin[position] > 0
      end
      
      if padding.has_key? position
        css["padding-#{position}".to_sym] = "#{padding[position]}px" if padding[position] > 0
      end  
    end
    
    css
  end
  
  # For css
  def offset_box_spacing
    offset_box_spacing = {:top => 0, :left => 0}
    
    if not self.offset_box_buffer.nil? and not self.offset_box_buffer.empty?
      offset_box_object = BoundingBox.depickle self.offset_box_buffer
      if self.bounds.top - offset_box_object.top > 0
        offset_box_spacing[:top] = ( self.bounds.top - offset_box_object.top)
      end
      
      if self.bounds.left - offset_box_object.left > 0
        offset_box_spacing[:left] = (self.bounds.left - offset_box_object.left)
      end
    end

    if self.root == true
      Log.info self.bounds
      offset_box_spacing[:top]    += self.bounds.top
      offset_box_spacing[:left]   += self.bounds.left
    end
    
    offset_box_spacing
  end

  def is_single_line_text
    if not self.render_layer.nil? and
      not (Layer.find self.render_layer).has_newline?
        return true
    else
      return false
    end
  end
  
  # Width subtracted by padding
  def unpadded_width
    if self.bounds.nil? or self.bounds.width.nil?
      nil 
    else
      padding = padding_from_child
      self.bounds.width - (padding[:left] + padding[:right])
    end
  end
  
  # Height subtracted by padding
  def unpadded_height
    if self.bounds.nil? or self.bounds.height.nil?
      nil 
    else
      padding = padding_from_child
      self.bounds.height - (padding[:top] + padding[:bottom])
    end
  end
  
  def set_width_class
    if not self.unpadded_width.nil?
      # Add a buffer of (960 + 10), because setting width of 960 in photoshop
      # is giving 962 in extendscript json. Debug more.
      if unpadded_width != 0 and unpadded_width <= 970
          self.width_class = StylesHash.get_bootstrap_width_class(unpadded_width)
      end
    end
  end
  
  # If the width has already not been set, set the width.
  # TODO Find out if there is any case when width is set.
  
  def width_css(css)
    if not css.has_key? :width and not is_single_line_text and not unpadded_width.nil? and unpadded_width != 0
        return {:width => unpadded_width.to_s + 'px'}
    end
    
    return {}
  end
  
  def get_css_properties
    if self.css_properties.nil?
      css = {}

      self.style_layers.each do |layer_id|
        layer = Layer.find layer_id
        css.update layer.get_css({}, self.is_leaf?, self)
      end
      
      css.update width_css(css)
      css.delete :width if is_single_line_text
      
      # Positioning
      positioned_grid_count = (self.children.select { |grid| grid.is_positioned }).length
      css[:position] = 'relative' if positioned_grid_count > 0
      
      css.update CssParser::position_absolutely(self) if is_positioned

      # Gives out the values for spacing the box model.
      # Margin and padding
      css.update spacing_css

      self.css_properties = css.to_json.to_s
      self.save!
    end

    css = JSON.parse self.css_properties, :symbolize_keys => true
    return css
  end
  
  # FIXME CSSTREE
  def get_css_classes
    if self.generated_css_classes.nil?
      grid_style_class = StylesHash.add_and_get_class CssParser::to_style_string self.get_css_properties

      css_classes = []

      # Set pull-left.
      css_classes.push 'pull-left' if not self.parent.nil? and self.parent.orientation == Constants::GRID_ORIENT_LEFT
      css_classes.push grid_style_class if not grid_style_class.nil?

      self.generated_css_classes = css_classes.to_json.to_s
      self.save!
    end
    
    css_classes = JSON.parse self.generated_css_classes
    return css_classes
  end
  
end