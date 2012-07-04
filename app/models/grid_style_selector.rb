class GridStyleSelector
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated  

  embedded_in :grid

  field :css_rules, :type => Hash, :default => {}
  field :extra_selectors, :type => Array, :default => []
  field :generated_selector, :type => String

  ## Spacing and padding related methods
   
  # Find out bounding box difference from it and its children.
  def padding_from_child
    non_style_layers = self.grid.layers.to_a.select do |layer|
      not self.grid.style_layers.to_a.include? layer.id.to_s
    end
    
    children_bounds = non_style_layers.collect { |layer| layer.bounds }
    children_superbound = BoundingBox.get_super_bounds children_bounds
    spacing = { :top => 0, :left => 0, :bottom => 0, :right => 0 }
    
    if not self.grid.bounds.nil? and not children_superbound.nil?
      spacing[:top]     = (children_superbound.top  - self.grid.bounds.top)
      spacing[:bottom]  = (self.grid.bounds.bottom - children_superbound.bottom)
      
      spacing[:left]  = (children_superbound.left - self.grid.bounds.left) 
      spacing[:right] = (self.grid.bounds.right - children_superbound.right)
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
    
    if not self.grid.offset_box_buffer.nil? and not self.grid.offset_box_buffer.empty?
      offset_box_object = BoundingBox.depickle self.grid.offset_box_buffer
      if self.grid.bounds.top - offset_box_object.top > 0
        offset_box_spacing[:top] = ( self.grid.bounds.top - offset_box_object.top)
      end
      
      if self.grid.bounds.left - offset_box_object.left > 0
        offset_box_spacing[:left] = (self.grid.bounds.left - offset_box_object.left)
      end
    end

    if self.grid.root == true
      offset_box_spacing[:top]    += self.grid.bounds.top
      offset_box_spacing[:left]   += self.grid.bounds.left
    end
    
    offset_box_spacing
  end

  def is_single_line_text
    if not self.grid.render_layer.nil? and
      not (Layer.find self.grid.render_layer).has_newline?
        return true
    else
      return false
    end
  end
  
  # Width subtracted by padding
  def unpadded_width
    if self.grid.bounds.nil? or self.grid.bounds.width.nil?
      nil 
    else
      padding = padding_from_child
      self.grid.bounds.width - (padding[:left] + padding[:right])
    end
  end
  
  # Height subtracted by padding
  def unpadded_height
    if self.grid.bounds.nil? or self.grid.bounds.height.nil?
      nil 
    else
      padding = padding_from_child
      self.grid.bounds.height - (padding[:top] + padding[:bottom])
    end
  end
  
  # If the width has already not been set, set the width.
  # TODO Find out if there is any case when width is set.
  
  def width_css(css)
    if not css.has_key? :width and not is_single_line_text and
      not unpadded_width.nil? and unpadded_width != 0
     
      return {:width => unpadded_width.to_s + 'px'}
    end
    
    return {}
  end
  
  def set_style_rules
    css = {}

    self.grid.style_layers.each do |layer_id|
      layer = Layer.find layer_id
      css.update layer.get_css(self)
    end
    
    css.update width_css(css)
    css.delete :width if is_single_line_text
    
    # Positioning
    positioned_grid_count = (self.grid.children.select { |grid| grid.is_positioned }).length
    css[:position] = 'relative' if positioned_grid_count > 0
    self.extra_selectors.push('pull-left') if not (self.grid.parent.nil?) and (self.grid.parent.orientation == Constants::GRID_ORIENT_LEFT)
    
    css.update CssParser::position_absolutely(grid) if grid.is_positioned

    self.extra_selectors.push('row') if not self.grid.children.empty? and self.grid.orientation == Constants::GRID_ORIENT_LEFT
    
    # Gives out the values for spacing the box model.
    # Margin and padding
    css.update spacing_css

    self.generated_selector = CssParser::create_incremental_selector(self) if not css.empty?

    self.css_rules = css
    self.save!
  end
  

  # Walks recursively through the grids and creates
  def generate_css_tree
    set_style_rules

    if self.grid.render_layer.nil?
      self.grid.children.each { |child| child.style_selector.generate_css_tree }
    else
      render_layer_obj = Layer.find(self.grid.render_layer)
      render_layer_obj.set_css(self)
    end
  end

  # Selector names (includes default selector and extra selectors)
  def selector_names
    all_selectors = extra_selectors

    layer_has_css = false
    if self.grid.render_layer
      render_layer_obj = Layer.find(self.grid.render_layer)
      layer_has_css = true if not render_layer_obj.css_rules.empty?
    end

    if not self.generated_selector.nil?
      all_selectors.push self.generated_selector if not self.css_rules.empty?
    end

    all_selectors.uniq!

    all_selectors
  end

  # Bubble up repeating css properties. No approximation now.
  def bubble_up_repeating_styles
    rule_repeat_hash = {}

    # Consider render layers also.
    grid.children.each do |child|
      child.style_selector.css_rules.each do |css_property, css_value|
        css_rule_hash_key = ({ css_property.to_sym => css_value }).to_json

        rule_repeat_hash[css_rule_hash_key] ||= 0
        rule_repeat_hash[css_rule_hash_key] = rule_repeat_hash[css_rule_hash_key] + 1
      end
    end

    # Trim out the non-repeating properties.
    rule_repeat_hash.each { |rule, repeats| rule_repeat_hash.delete rule if repeats != grid.children.length }
   
    # Remove all the repeating properties from the children 
    rule_repeat_hash.each do |rule, repeat_count|
      rule_object = (JSON.parse rule, :symbolize_names => true)
      rule_key    = rule_object.keys.first
      grid.children.each do |child|
        child.style_selector.css_rules.delete rule_key
        if not child.render_layer.nil?
          layer_obj = Layer.find child.render_layer
          layer_obj.css_rules.delete rule_key.to_s
          layer_obj.save!
        end
      end
      Log.info "Deleted #{rule_key} from #{grid.to_short_s}"
      self.css_rules.update rule_object
    end

    grid.save!
  end

  # Group up font-family, etc from bottom most nodes and group them up
  # Go through all the grids post order, with root node as the last node. 
  def group_css_properties
    grid.children.each { |kid| kid.style_selector.group_css_properties }

    bubble_up_repeating_styles
  end

  def sass_tree(tabs = 1)
    child_sass_trees = ''
    self.grid.children.each do |child|
      child_sass_trees += child.style_selector.sass_tree(tabs + 1)
    end

    spaces = ""
    for tab in [0..tabs]
      spaces = spaces + " "
    end

    if self.css_rules.empty? or self.generated_selector.nil?
      sass = "#{spaces} #{child_sass_trees}"
    else
      css_rules_string = CssParser::to_style_string(self.css_rules).gsub(";",";\n#{spaces}")
      sass = <<sass
#{spaces}.#{self.generated_selector} {
#{spaces}  #{CssParser::to_style_string(self.css_rules)}
#{spaces}  #{child_sass_trees}
#{spaces}}
sass
    end

    if not self.grid.render_layer.nil?
      layer = (Layer.find self.grid.render_layer)
      if (not layer.css_rules.empty?) and (not layer.generated_selector.nil?)
        css_rules_string = CssParser::to_style_string(layer.css_rules).gsub(";",";\n#{spaces}")
        sass += <<sass
#{spaces}.#{layer.generated_selector} {
#{spaces}  #{css_rules_string}
#{spaces}}
sass
      end
    end

    sass
  end
  
end