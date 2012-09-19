class GridStyle

  attr_accessor :grid

  attr_accessor :computed_css # (Hash) 
  attr_accessor :extra_selectors # (Array) 
  attr_accessor :css_rules # (Array)
  attr_accessor :generated_selector # (String) 

  def initialize(args)
    @grid   = args[:grid]
    if @grid.nil?
      raise ArgumentError, "No grid object passed"
    end

    @computed_css = {}
    @extra_selectors    = args.fetch :extra_selectors, []
    @generated_selector = args.fetch :generated_selector, nil
  end

  def attribute_data
    {
      :generated_selector => @generated_selector
    }
  end

  def to_s
    "#{@generated_selector}"
  end

  # FIXME PSDJS
  ## helper methods
  def get_border_width
    border_width = nil
    if self.computed_css.has_key? :border
      border_properties = self.computed_css.fetch(:border).split
      border_width_str = border_properties[0].scan(/\d+/).first
      if not border_width_str.nil?
        border_width = border_width_str.to_i
      end
    end
    return border_width
  end
  
  ## Spacing and padding related method
  # Find out bounding box difference from it and its children.
  def get_padding
    non_style_layers = self.grid.layers.values - self.grid.style_layers.values
    
    children_bounds = non_style_layers.collect { |layer| layer.bounds }
    children_superbound = BoundingBox.get_super_bounds children_bounds
    padding = { :top => 0, :left => 0, :bottom => 0, :right => 0 }
    
    if not self.grid.bounds.nil? and not children_superbound.nil?
      padding[:top]    = (children_superbound.top  - self.grid.bounds.top)
      padding[:bottom] = (self.grid.bounds.bottom - children_superbound.bottom)
      padding[:left]   = (children_superbound.left - self.grid.bounds.left) 
      padding[:right]  = (self.grid.bounds.right - children_superbound.right)
      

      border_width = self.get_border_width
      if not border_width.nil?
        padding[:top]    -= border_width
        padding[:bottom] -= border_width
        padding[:left]   -= border_width
        padding[:right]  -= border_width
      end
    end
    padding
  end
  
  def get_margin
    #TODO. Margin is not always from left and top. It is from all sides.

    margin = {:top => 0, :left => 0}
    if self.grid.root == true
      margin[:top]  += self.grid.bounds.top
      margin[:left] += self.grid.bounds.left
    else
      margin_boxes = []

      if not self.grid.offset_box.nil?
        margin_boxes.push self.grid.offset_box
      end

      if not self.grid.grouping_box.nil?
        margin_boxes.push self.grid.grouping_box
      end      
      
      if not margin_boxes.empty?
        children_bounds     = self.grid.layers.values.collect { |layer| layer.bounds }
        children_superbound = BoundingBox.get_super_bounds children_bounds        
        margin_superbound   = BoundingBox.get_super_bounds margin_boxes
           
        if not margin_superbound.nil? and not children_superbound.nil?
          margin[:top] = children_superbound.top - margin_superbound.top
          margin[:left] = children_superbound.left - margin_superbound.left
        end
      end
    end
    return margin
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
  def set_white_space
    margin  = get_margin
    padding = get_padding

    positions = [:top, :left, :bottom, :right]

    spacing = {}
    positions.each do |position|
      if margin.has_key? position
        spacing["margin-#{position}".to_sym] = "#{margin[position]}px" if margin[position] > 0
      end
      
      if padding.has_key? position
        spacing["padding-#{position}".to_sym] = "#{padding[position]}px" if padding[position] > 0
      end  
    end
    
    return spacing
  end
  
  
  # Width subtracted by padding
  def unpadded_width
    width = 0

    if not self.grid.bounds.nil? and not self.grid.bounds.width.nil?
      padding = self.get_padding

      width += self.grid.bounds.width
      width -= padding[:left] + padding[:right]
      
    end
    return width
  end
  
  # Height subtracted by padding
  def unpadded_height
    height = 0

    if not self.grid.bounds.nil? and not self.grid.bounds.width.nil?
      padding = self.get_padding

      height += self.grid.bounds.height
      height -= padding[:top] + padding[:bottom]
    end
    return height
  end

  # If the width has already not been set, set the width
  def set_width
    width = self.unpadded_width

    if not width.nil? and width != 0
      grouping_box = self.grid.grouping_box
      has_trailing_offset = false
      has_trailing_offset = (self.grid.bounds != grouping_box) unless grouping_box.nil? or self.grid.bounds.nil?
      return { :width => width.to_s + 'px' }
    end
    return {}
  end
  
  def set_height
    height = self.unpadded_height
    
    if not height.nil? and height != 0
      return :height => height.to_s + "px"
    end
    
    return {}
  end
  
  def set_min_dimensions
    width = self.unpadded_width
    height = self.unpadded_height
    return { :'min-height' => "#{height}px", :'min-width' => "#{width}px" }
  end

  # Array of CSS rules, created using 
  # computed using computed css and 
  def css_rules
    rules_array = []
    self.computed_css.each do |rule_key, rule_object|
      rules_array.concat Compassify::get_scss(rule_key, rule_object)
    end
    

    self.grid.style_layers.values.each do |layer|
      rules_array += layer.css_rules
    end

    rules_array
  end

  def set_style_rules
    style_rules = {}

    set_shape_dimensions_flag = false

    # Checking if the style layers had a shape.
    if self.computed_css.has_key? :'min-width' or self.computed_css.has_key? :'min-height'
      style_rules.delete :'min-width'
      style_rules.delete :'min-height'
      set_shape_dimensions_flag = true
    end
    
    # Positioning - absolute is handled separately. Just find out if a grid has to be relatively positioned
    position_relatively = false
    if self.grid.has_positioned_children? or self.grid.has_positioned_siblings?
      position_relatively = true
    end
    
    if not self.grid.parent.nil?
      parent = self.grid.parent
      if parent.style.computed_css.has_key? 'position' and parent.style.computed_css.fetch('position') == 'relative'
        position_relatively = true
      elsif parent.positioned
        position_relatively = true
      end
    end

    if position_relatively
      style_rules.update  :position => 'relative', :'z-index' => self.grid.zindex
    end
    
    # float left class if parent is set to GRID_ORIENT_LEFT
    if not self.grid.root and (self.grid.parent.orientation == Constants::GRID_ORIENT_LEFT)
      self.extra_selectors.push 'pull-left'
    end
    
    # Handle absolute positioning now
    style_rules.update position_absolutely if grid.positioned

    self.extra_selectors.push('row') if not self.grid.children.empty? and self.grid.orientation == Constants::GRID_ORIENT_LEFT
    
    # Margin and padding
    style_rules.update self.set_white_space
    
    # set width for the grid
    style_rules.update self.set_width
    
    # set height only if there are positioned children
    style_rules.update self.set_height if self.grid.has_positioned_children?
    
    # minimum height and width for shapes in style layers
    style_rules.update self.set_min_dimensions if set_shape_dimensions_flag

    self.computed_css.update style_rules

    self.generated_selector = CssParser::create_incremental_selector('wrapper') if (not self.computed_css.empty?) and self.generated_selector.nil?
  end

  def position_absolutely
    css = {}
    if self.grid.bounds and not self.grid.zindex.nil?
      css[:position]  = 'absolute'
      css[:top]       = (self.grid.bounds.top - self.grid.parent.bounds.top + 1).to_s + 'px'
      css[:left]      = (self.grid.bounds.left - self.grid.parent.bounds.left + 1).to_s + 'px'
      css[:'z-index'] = self.grid.zindex
    end

    css
  end

  def crop_images
    self.grid.style_layers.each do |_, layer|
      layer.crop_objects_for_cropped_bounds
    end
  end
  
  # Walks recursively through the grids and creates
  def compute_css
    self.set_style_rules

    self.grid.style_layers.each do |_, layer|
      layer.set_style_rules
    end


    if self.grid.render_layer.nil?
      self.grid.children.values.each { |child| child.style.compute_css }
    else
      self.grid.render_layer.set_style_rules
    end
  end

  def is_text_rule?(rule)
    rule.to_s.index('font-') != nil
  end

  def get_text_containing_grids(grids)
    grids_array = grids.to_a
    text_containing_grids = grids_array.select do |grid|
      if grid.is_text_grid?
        true
      else
        has_font_property = false
        grid.style.computed_css.each do |rule, value|
          if is_text_rule?(rule)
            has_font_property = true
            break
          end
        end

        has_font_property
      end
    end

    text_containing_grids
  end

  # Selector names array(includes default selector and extra selectors)
  def selector_names
    all_selectors = self.extra_selectors

    layer_has_css = false
    if self.grid.render_layer
      layer_has_css = true if not self.grid.render_layer.computed_css.empty?
    end

    all_selectors.push self.generated_selector if not self.css_rules.empty?

    all_selectors.uniq!

    all_selectors
  end

  def scss_tree(tabs = 0)
    child_scss_trees = ''
    self.grid.children.values.each do |child|
      child_scss_trees += child.style.scss_tree(tabs + 1)
    end

    spaces = ""
    for tab in 0..(tabs-1)
      spaces = spaces + " "
    end

    css_rules = self.css_rules

    if css_rules.length == 0
      sass = "#{child_scss_trees}"
    else
      css_string = css_rules.join(";\n") + ";"
      child_css_string = ""
      if not child_scss_trees.empty?
         child_css_string = "\n#{spaces}" + child_scss_trees.rstrip
      end

      initial_space = "  "
      initial_space = "" if self.grid.root == true

      sass = <<sass
#{initial_space}.#{self.generated_selector} {
#{css_string}#{child_css_string}
#{spaces}}
sass
    end

    if not self.grid.render_layer.nil?
      render_layer = self.grid.render_layer
      chunk_text_rules = render_layer.chunk_text_rules
      css_rules = render_layer.css_rules
      if not css_rules.length == 0
        layer_css_string = css_rules.join(";\n") + ";"
        sass += <<sass
 .#{render_layer.generated_selector} {
#{layer_css_string}
#{spaces}}
sass
      end

      if not render_layer.text.nil?
        sass += chunk_text_rules
      end

    end

    sass
  end
  
end