class GridStyleSelector
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated  

  embedded_in :grid

  field :css_rules, :type => Hash, :default => {}
  field :extra_selectors, :type => Array, :default => []
  field :generated_selector, :type => String

  field :hashed_selectors, :type => Array, :default => []


  ## helper methods
  def get_border_width
    border_width = nil
    if self.css_rules.has_key? :border
      border_properties = self.css_rules.fetch(:border).split
      border_width_str = border_properties[0].scan(/\d+/).first
      if not border_width_str.nil?
        border_width = border_width_str.to_i
      end
    end
    return border_width
  end
  
  def is_single_line_text
    if not self.grid.render_layer.nil? and
        (Layer.find self.grid.render_layer).kind == Layer::LAYER_TEXT and
        not (Layer.find self.grid.render_layer).has_newline? and
        (Layer.find self.grid.render_layer).text_type != "TextType.PARAGRAPHTEXT"
      return true
    else
      return false
    end
  end

  ## Spacing and padding related method
   
  # Find out bounding box difference from it and its children.
  def get_padding
    non_style_layers = self.grid.layers.to_a.select do |layer|
      not self.grid.style_layers.to_a.include? layer.id.to_s
    end
    
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

      if not self.grid.offset_box_buffer.nil?
        margin_boxes.push BoundingBox.depickle self.grid.offset_box_buffer
      end

      if not self.grid.grouping_box.nil?
        margin_boxes.push BoundingBox.depickle self.grid.grouping_box
      end      
      
      if not margin_boxes.empty?
        children_bounds     = self.grid.layers.collect { |layer| layer.bounds }
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
      grouping_box = BoundingBox.depickle self.grid.grouping_box
      has_trailing_offset = false
      has_trailing_offset = (self.grid.bounds != grouping_box) unless grouping_box.nil? or self.grid.bounds.nil?
      if self.is_single_line_text and not has_trailing_offset
        return { :width => width.to_s + 'px' }
      else
        return { :width => width.to_s + 'px' }
      end
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

  # Selector names are usually generated,
  # but when the user edits the selector name (aka class name)
  # we want to pick it up from the modified selector map
  # and return
  def modified_generated_selector
    modified_selector_name = self.grid.design.selector_name_map[self.generated_selector]
    if not modified_selector_name.nil?
      modified_selector_name["name"]
    else
      self.generated_selector
    end
  end

  def set_style_rules
    style_rules = {}
    self.grid.style_layers.each do |layer_id|
      layer = Layer.find layer_id
      style_rules.update layer.get_style_rules(self)
    end

    set_shape_dimensions_flag = false

    # Checking if the style layers had a shape.
    if self.css_rules.has_key? :'min-width' or self.css_rules.has_key? :'min-height'
      style_rules.delete :'min-width'
      style_rules.delete :'min-height'
      set_shape_dimensions_flag = true
    end
    
    # Positioning - absolute is handled separately. Just find out if a grid has to be relatively positioned
    position_relatively = false
    #FIXME Sink
    if self.grid.has_positioned_children? or self.grid.has_positioned_siblings?
      position_relatively = true
    end
    
    if not self.grid.parent.nil?
      parent = self.grid.parent
      parent_selector = parent.style_selector
      if parent_selector.css_rules.has_key? 'position' and parent_selector.css_rules.fetch('position') == "relative"
        position_relatively = true
      elsif parent.is_positioned
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
    style_rules.update CssParser::position_absolutely(grid) if grid.is_positioned

    #FIXME Sink
    self.extra_selectors.push('row') if not self.grid.children.empty? and self.grid.orientation == Constants::GRID_ORIENT_LEFT
    
    # Margin and padding
    style_rules.update self.set_white_space
    
    # set width for the grid
    #FIXME Sink
    style_rules.update self.set_width
    
    # set height only if there are positioned children
    #FIXME Sink 
    style_rules.update self.set_height if self.grid.has_positioned_children?
    
    # minimum height and width for shapes in style layers
    style_rules.update self.set_min_dimensions if set_shape_dimensions_flag

    self.css_rules.update style_rules
    self.save!

    self.generated_selector = CssParser::create_incremental_selector if not self.css_rules.empty?
        
    CssParser::add_to_inverted_properties(self.css_rules, self.grid)
  end
  
  # Walks recursively through the grids and creates
  def generate_css_tree
    Log.info "Setting style rules for #{self.grid}..."
    self.set_style_rules

    if self.grid.render_layer.nil?
      self.grid.children.each { |child| child.style_selector.generate_css_tree }
    else
      render_layer_obj = Layer.find(self.grid.render_layer)
      render_layer_obj.set_style_rules(self)
    end
  end

  # Bubble up repeating css properties.
  def bubbleup_repeating_styles
    rule_repeat_hash = {}

    # Consider render layers also.
    grid.children.each do |child|
      rules_hash = child.style_selector.css_rules
      rules_hash = (Layer.find child.render_layer).css_rules if not child.render_layer.nil?
      rules_hash.each do |css_property, css_value|
        css_rule_hash_key = ({ css_property.to_sym => css_value }).to_json

        rule_repeat_hash[css_rule_hash_key] ||= 0
        rule_repeat_hash[css_rule_hash_key] = rule_repeat_hash[css_rule_hash_key] + 1
      end
    end

    rule_repeat_hash.each do |rule, repeats|
      rule_repeat_hash.delete rule if repeats == 0
    end

    bubbleable_rules = []
    # Trim out the non-repeating properties.
    rule_repeat_hash.each do |rule, repeats|
      rule_key = (JSON.parse rule).keys.first
      if is_text_rule?(rule_key)
        child_grids = get_text_containing_grids grid.children
      else
        child_grids = grid.children
      end

      if repeats > (child_grids.length * 0.6)
        if (Constants::css_properties.has_key? rule_key.to_sym and Constants::css_properties[rule_key.to_sym][:inherit])
          bubbleable_rules.push rule
          Log.debug "Bubbling up #{rule}"
        end   
      end 
    end

    # Remove all the repeating properties from the children
    # JSON parse happening everytime. Optimize later
    bubbleable_rules.each do |rule|
      rule_object = (JSON.parse rule, :symbolize_names => true)
      rule_key    = rule_object.keys.first
      rule_value  = rule_object[rule_key]

      grid.children.each do |child|
        # Delete from the grid css.
        if child.style_selector.css_rules[rule_key] == rule_value
          child.style_selector.css_rules.delete rule_key
          if DesignGlobals.instance.css_properties_inverted.has_key? rule
            DesignGlobals.instance.css_properties_inverted[rule].delete child
          end

          child.save!
        end

        if not child.render_layer.nil?
          layer_obj = Layer.find child.render_layer
          if layer_obj.css_rules[rule_key.to_s] == rule_value
            layer_obj.css_rules.delete rule_key.to_s
            if DesignGlobals.instance.css_properties_inverted.has_key? rule
              DesignGlobals.instance.css_properties_inverted[rule].delete child
            end

            layer_obj.save!
          end
        end
      end

      if not DesignGlobals.instance.css_properties_inverted[rule].nil? and DesignGlobals.instance.css_properties_inverted[rule].empty?
        DesignGlobals.instance.css_properties_inverted.delete rule
      end

      Log.debug "Deleted #{rule_key} from #{grid.to_short_s}"
    end

    bubbleable_rules.each do |rule|
      rule_object = (JSON.parse rule, :symbolize_names => true)
      self.css_rules.update rule_object
    end


    grid.save!
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
        grid.style_selector.css_rules.each do |rule, value|
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


  # How hashing works
  # While collecting all css rules, keep adding to a global table which has the frequency
  # set.
  #
  # While grouping, remove these items from the frequency sets which were grouped.
  # After grouping, remove all the properties which have only one item it it. These are unique
  # items.
  #
  # LATER TODO:
  # Figure out how to fork this into multiple processes on to single 
  # heroku stack using double boiler or supervisord or normal fork
  # http://www.ruby-doc.org/core-1.9.3/Kernel.html#method-i-fork
  # 
  def hash_css_properties
    Log.info "Generating CSS hashes"
    design_hashed_selector_hash = {}

    apriori = Apriori.new(DesignGlobals.instance.css_properties_inverted, 2)
    apriori.calculate_frequent_itemsets
    max_association_match = apriori.max_association_match
    class_groups = apriori.get_class_groups(max_association_match)
    class_groups.each do |rules, nodes|
      rule_hash = {}
      rules.each { |rule| rule_hash.update (JSON.parse rule, :symbolize_names => true) }
      next_selector_name = CssParser::create_incremental_selector
      design_hashed_selector_hash[next_selector_name] = rule_hash
      nodes.each do |node|
        node.style_selector.hashed_selectors.push next_selector_name
        Log.info "Adding #{next_selector_name} to #{node.to_short_s}"
        node.save!
      end
    end

    design_hashed_selector_hash
  end

  # Finds out subset CSS rules which are not taken care by 
  # the grouping selector
  def get_subset_css_rules(css_hash)
    original_css_array = CssParser::rule_hash_to_array(css_hash)
    css_array          = original_css_array.clone
    Log.info "#{css_array.length} existing rules"
    self.hashed_selectors.each do |selector|
      hashed_css_array  = CssParser::rule_hash_to_array(self.grid.design.hashed_selectors[selector])
      Log.info "#{css_array} vs #{hashed_css_array}"
      css_array         = css_array - hashed_css_array
      Log.info "Post reduction #{css_array}"
      # This might cause bug when there are more than one group selector
      overridable_items = hashed_css_array - original_css_array
      overridable_items.each do |rule|
        rule_object = JSON.parse rule, :symbolize_names => true
        rule_key    = rule_object.keys.first
        if Constants::css_properties.has_key? rule_key.to_sym
          overridable_rule = {rule_key => Constants::css_properties[rule_key.to_sym][:initial]}.to_json
          Log.info "Overridable rule = #{overridable_rule}"
          css_array.push(overridable_rule)
        end
      end
    end

    # reverse the array, so that the items which belong to original css_array come in the last
    # and while converting them into hash, they get priority and overriden items don't.
    css_array.reverse! 

    Log.info "#{css_array.length} reduced rules. Contents = #{css_array}"

    CssParser::rule_array_to_hash(css_array)
  end

  # Recursive function, to be called after hash_css_properties has been called.
  #
  # Once the css_hashes are calculated, remove the redundant items and override 
  # any style that was added by the grouped css class.
  def reduce_hashed_css_properties
    Log.info "Reducing hashed properties for #{self.grid.to_short_s}"
    if self.grid.render_layer
      render_layer_obj = Layer.find self.grid.render_layer
      render_layer_obj.css_rules =  get_subset_css_rules(render_layer_obj.css_rules)
      render_layer_obj.save!
    else
      self.css_rules = get_subset_css_rules(self.css_rules)
      self.save!

      self.grid.children.each do |child|
        child.style_selector.reduce_hashed_css_properties
      end
    end
  end

  def modified_hashed_selector
    design = Design.find self.grid.design.id
    modified = self.hashed_selectors.map { |selector| design.selector_name_map[selector]['name'] }
    modified
  end

  # Selector names array(includes default selector and extra selectors)
  def selector_names
    all_selectors = self.extra_selectors + self.modified_hashed_selector

    layer_has_css = false
    if self.grid.render_layer
      render_layer_obj = Layer.find(self.grid.render_layer)
      layer_has_css = true if not render_layer_obj.css_rules.empty?
    end

    if not self.generated_selector.nil?
      all_selectors.push self.modified_generated_selector if not self.css_rules.empty?
    end

    all_selectors.uniq!

    all_selectors
  end


  # Group up font-family, etc from bottom most nodes and group them up
  # Go through all the grids post order, with root node as the last node.
  # Bubble up. 
  def bubbleup_css_properties
    self.grid.children.each { |kid| kid.style_selector.bubbleup_css_properties }

    bubbleup_repeating_styles
  end

  def generate_initial_selector_name_map
    selector_hash = {}
    initial_selector_name = nil
    if self.grid.render_layer
      render_layer_obj = Layer.find self.grid.render_layer
      initial_selector_name = (render_layer_obj.generated_selector) if not render_layer_obj.generated_selector.nil?
      css = render_layer_obj.css_rules.clone
    else
      initial_selector_name = (generated_selector) if not generated_selector.nil? and not generated_selector.empty?
      css = self.css_rules.clone
    end

    if not initial_selector_name.nil?
      selector_hash = { initial_selector_name => {"name" => initial_selector_name, "css" => css } }
    end


    self.grid.children.each do |child|
      selector_hash.update(child.style_selector.generate_initial_selector_name_map)
    end

    selector_hash
  end

  def scss_tree(tabs = 0)
    child_scss_trees = ''
    self.grid.children.each do |child|
      child_scss_trees += child.style_selector.scss_tree(tabs + 1)
    end

    spaces = ""
    for tab in 0..(tabs-1)
      spaces = spaces + " "
    end

    if self.css_rules.empty? or self.generated_selector.nil?
      sass = "#{child_scss_trees}"
    else
      css_rules_string = CssParser::to_style_string(self.css_rules, spaces + "  ")
      child_css_string = ""
      if not child_scss_trees.empty?
         child_css_string = "\n#{spaces}" + child_scss_trees.rstrip
      end

      initial_space = "  "
      initial_space = "" if self.grid.root == true

      sass = <<sass
#{initial_space}.#{self.modified_generated_selector} {
#{css_rules_string}#{child_css_string}
#{spaces}}
sass
    end

    if not self.grid.render_layer.nil?
      layer = (Layer.find self.grid.render_layer)
      chunk_text_rules = layer.chunk_text_rules
      if (not layer.css_rules.empty?) and (not layer.generated_selector.nil?)
        css_rules_string = CssParser::to_style_string(layer.css_rules, spaces + '  ')
        sass += <<sass
 .#{layer.modified_generated_selector(self.grid)} {
#{css_rules_string}
#{spaces}}#{chunk_text_rules}
sass
      end
    end

    sass
  end
  
end