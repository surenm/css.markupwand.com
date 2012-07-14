class GridStyleSelector
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated  

  embedded_in :grid

  field :css_rules, :type => Hash, :default => {}
  field :extra_selectors, :type => Array, :default => []
  field :generated_selector, :type => String

  field :hashed_selectors, :type => Array, :default => []

  ## Spacing and padding related methods
   
  # Find out bounding box difference from it and its children.
  def get_padding
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
  
  def get_margin
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
  def spacing_css
    #TODO. Margin and padding are not always from
    # left and top. It is from all sides.
    margin  = get_margin
    padding = get_padding
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
  

  def is_single_line_text
    if not self.grid.render_layer.nil? and
      (Layer.find self.grid.render_layer).kind == Layer::LAYER_TEXT and
      not (Layer.find self.grid.render_layer).has_newline?
        return true
    else
      return false
    end
  end
  
  # Width subtracted by padding
  def unpadded_width
    width = 0

    if not self.grid.bounds.nil? and not self.grid.bounds.width.nil?
      width += self.grid.bounds.width
      
      padding = get_padding
      width -= padding[:left] + padding[:right]
      
      grouping_box = BoundingBox.depickle self.grid.grouping_box
      if not grouping_box.nil?
        initial_offset = self.grid.bounds.left - grouping_box.left
        width += initial_offset
      end
    end
    return width
  end
  
  # Height subtracted by padding
  def unpadded_height
    height = 0

    if not self.grid.bounds.nil? and not self.grid.bounds.width.nil?
      height += self.grid.bounds.height
      
      padding = get_padding
      height -= padding[:top] + padding[:bottom]
      
    end
    return height

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
    css = {}

    self.grid.style_layers.each do |layer_id|
      layer = Layer.find layer_id
      css.update layer.get_style_rules(self)
    end
    
    css.update width_css(css)
    
    # Positioning - absolute is handled separately. Just find out if a grid has to be relatively positioned
    positioned_children = self.grid.children.select { |child_grid| child_grid.is_positioned }

    positioned_siblings = []
    if not self.grid.root and not self.grid.is_positioned
      positioned_siblings = self.grid.parent.children.select { |sibling_grid| sibling_grid.is_positioned }
    end

    if positioned_children.size > 0 or positioned_siblings.size > 0
      css[:position]  = 'relative'
      css[:"z-index"] = self.grid.zindex
    end
    
    # float left class if parent is set to GRID_ORIENT_LEFT
    if not self.grid.root and (self.grid.parent.orientation == Constants::GRID_ORIENT_LEFT)
      self.extra_selectors.push 'pull-left'
    end
    
    # Handle absolute positioning now
    css.update CssParser::position_absolutely(grid) if grid.is_positioned

    self.extra_selectors.push('row') if not self.grid.children.empty? and self.grid.orientation == Constants::GRID_ORIENT_LEFT
    
    # Gives out the values for spacing the box model.
    # Margin and padding
    css.update spacing_css

    self.generated_selector = CssParser::create_incremental_selector if not css.empty?

    self.css_rules = css
    
    CssParser::add_to_inverted_properties(css, self.grid)

    self.save!
  end
  
  # Walks recursively through the grids and creates
  def generate_css_tree
    Log.info "Setting style rules for #{self.grid}..."
    set_style_rules

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
      child.style_selector.css_rules.each do |css_property, css_value|
        css_rule_hash_key = ({ css_property.to_sym => css_value }).to_json

        rule_repeat_hash[css_rule_hash_key] ||= 0
        rule_repeat_hash[css_rule_hash_key] = rule_repeat_hash[css_rule_hash_key] + 1
      end
    end

    rule_repeat_hash.each do |rule, repeats|
      if repeats == 0
        rule_repeat_hash.delete rule
      end
    end

    bubbleable_rules = []
    # Trim out the non-repeating properties.
    rule_repeat_hash.each do |rule, repeats|
      rule_key = (JSON.parse rule).keys.first
      if repeats > (grid.children.length * 0.6)
        if (Constants::css_properties.has_key? rule_key.to_sym and Constants::css_properties[rule_key.to_sym][:inherit])
          bubbleable_rules.push rule
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
          DesignGlobals.instance.css_properties_inverted[rule].delete self.grid
        end

        if not child.render_layer.nil?
          layer_obj = Layer.find child.render_layer
          if layer_obj.css_rules[rule_key.to_s] == rule_value
            layer_obj.css_rules.delete rule_key.to_s
            DesignGlobals.instance.css_properties_inverted[rule].delete self.grid
            layer_obj.save!
          end
        end
      end

      if DesignGlobals.instance.css_properties_inverted[rule].empty?
        DesignGlobals.instance.css_properties_inverted.delete rule
      end

      Log.info "Deleted #{rule_key} from #{grid.to_short_s}"
    end

    bubbleable_rules.each do |rule|
      rule_object = (JSON.parse rule, :symbolize_names => true)
      self.css_rules.update rule_object
    end


    grid.save!
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

    apriori = Apriori.new(DesignGlobals.instance.css_properties_inverted, 2)
    apriori.calculate_frequent_itemsets
    max_association_match = apriori.max_association_match
    class_groups = apriori.get_class_groups(max_association_match)
    class_groups.each do |rules, nodes|
      rule_hash = {}
      rules.each { |rule| rule_hash.update (JSON.parse rule, :symbolize_names => true) }
      next_selector_name = CssParser::create_incremental_selector
      self.grid.design.hashed_selectors[next_selector_name] = rule_hash
      nodes.each do |node|
        node.style_selector.hashed_selectors.push next_selector_name
        Log.info "Adding #{next_selector_name} to #{node.to_short_s}"
        node.save!
      end
    end

    self.grid.design.save!
  end

  # Finds out subset CSS rules which are not taken care by 
  # the grouping selector
  def get_subset_css_rules(css_hash)
    original_css_array = CssParser::rule_hash_to_array(css_hash)
    css_array          = original_css_array.clone
    Log.info "#{css_array.length} existing rules"
    self.hashed_selectors.each do |selector|
      hashed_css_array  = CssParser::rule_hash_to_array(self.grid.design.hashed_selectors[selector])
      css_array         = css_array - hashed_css_array
      # This might cause bug when there are more than one group selector
      overridable_items = hashed_css_array - original_css_array
      overridable_items.each do |rule|
        rule_object = JSON.parse rule, :symbolize_names => true
        rule_key    = rule_object.keys.first
        if Constants::css_properties.has_key? rule_key.to_sym
          css_array.push({rule_key => Constants::css_properties[rule_key.to_sym][:initial]}.to_json)
        end
      end
    end
    Log.info "#{css_array.length} reduced rules"

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

  # Selector names array(includes default selector and extra selectors)
  def selector_names
    all_selectors = extra_selectors + hashed_selectors

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
    grid.children.each { |kid| kid.style_selector.bubbleup_css_properties }

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
    for tab in 0..tabs
      spaces = spaces + " "
    end

    if self.css_rules.empty? or self.generated_selector.nil?
      sass = "#{spaces}#{child_scss_trees}"
    else
      css_rules_string = CssParser::to_style_string(self.css_rules, spaces)
      sass = <<sass
#{spaces}.#{self.modified_generated_selector} {
#{spaces} #{css_rules_string}
#{spaces} #{child_scss_trees}
#{spaces}}
sass
    end

    if not self.grid.render_layer.nil?
      layer = (Layer.find self.grid.render_layer)
      if (not layer.css_rules.empty?) and (not layer.generated_selector.nil?)
        css_rules_string = CssParser::to_style_string(layer.css_rules, spaces)
        sass += <<sass
#{spaces}.#{layer.modified_generated_selector(self.grid)} {
#{spaces} #{css_rules_string}
#{spaces}}
sass
      end
    end

    sass
  end
  
end