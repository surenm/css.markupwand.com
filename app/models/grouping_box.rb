class GroupingBox < Tree::TreeNode

  def self.get_vertical_gutters(bounding_boxes)
    vertical_lines  = bounding_boxes.collect{|bb| bb.left}
    vertical_lines += bounding_boxes.collect{|bb| bb.right}
    vertical_lines.uniq!

    vertical_gutters = []
    vertical_lines.each do |vertical_line|
      is_gutter = true
      bounding_boxes.each do |bb|
        if bb.left < vertical_line and vertical_line < bb.right
          is_gutter = false
          break
        end
      end
      vertical_gutters.push vertical_line if is_gutter
    end
    vertical_gutters.sort!
  end


  def self.get_horizontal_gutters(bounding_boxes)
    horizontal_lines  = bounding_boxes.collect{|bb| bb.top}
    horizontal_lines += bounding_boxes.collect{|bb| bb.bottom}
    horizontal_lines.uniq!

    horizontal_gutters = []
    horizontal_lines.each do |horizontal_line|
      is_gutter = true
      bounding_boxes.each do |bb|
        if bb.top < horizontal_line and horizontal_line < bb.bottom
          is_gutter = false
          break
        end
      end
      horizontal_gutters.push horizontal_line if is_gutter
    end
    horizontal_gutters.sort!
  end

  def self.get_node(root_node, node_name)
    return root_node if root_node.name == node_name

    root_node.breadth_each do |node|
      next if node[node_name].nil?
      return node[node_name]
    end
  end

  # Assumes that all nodes belong in a same tree
  def self.get_common_ancestor(grouping_boxes)
    # first get all the parentages of the grouping boxes in root first order
    grouping_box_parentages = grouping_boxes.collect do |grouping_box| 
      grouping_box.parentage.reverse
    end
    
    # Algorithm to get the common ancestor. 
    # Keep iterating parentage array until parentages differ or we exhaust parentage arrays
    pos = 0
    while true
      pos_grouping_boxes = grouping_box_parentages.collect do |parentage| 
        gb = parentage.fetch pos, nil
        gb.bounds if not gb.nil?
      end

      uniq_boxes = pos_grouping_boxes.uniq

      break if uniq_boxes.size > 1
      break if uniq_boxes.size == 1 and uniq_boxes.first.nil?

      pos += 1
    end

    common_ancestor = grouping_box_parentages.first[pos - 1]
    return common_ancestor
  end

  def initialize(args)
    bounds = args.fetch :bounds
    @design = args.fetch :design
    super bounds.to_s, args
  end
  
  def unique_identifier
    layer_keys = self.layers.collect do |layer| layer.uid end
    raw_identifier = "#{layer_keys.join '-'}"
    digest = Digest::MD5.hexdigest raw_identifier
    return digest
  end

  def attribute_data
    layer_keys = self.layers.collect do |layer| layer.uid end
    
    children_tree = []
    self.children.each do |child|
      children_tree.push child.attribute_data
    end

    {
      :name => self.name,
      :label => self.name,
      :bounds => self.bounds,
      :orientation => self.orientation,
      :layers => layer_keys,
      :children => children_tree,
      :has_alternate_grouping => self.has_alternate_grouping,
      :has_intersecting_layers => self.has_intersecting_layers,
      :enable_alternate_grouping => self.enable_alternate_grouping
    }
  end

  def to_s
    layer_names = ''
    self.layers.each { |layer| layer_names += layer.name + ', ' }
    return "#{name} - [#{layer_names}]"
  end

  def get_child_index(child_node)
    self.children.to_a.find_index child_node
  end

  def layers
    self.content[:layers]
  end

  def layer_groups
    return [] if @design.layer_groups.nil?
    
    layers_set = self.layers.to_set
    grouping_box_layer_groups = Array.new
        
    @design.layer_groups.each do |key, layer_group|
      if layer_group.layers.to_set.proper_subset? layers_set
        grouping_box_layer_groups.push layer_group
      end
    end

    this_level_layer_groups = Array.new
    grouping_box_layer_groups.each do |gb_a|
      flag = true
      grouping_box_layer_groups.each do |gb_b|
        if gb_a.layers.to_set.proper_subset? gb_b.layers.to_set
          flag = false
          break
        end
      end

      if flag
        this_level_layer_groups.push gb_a
      end
    end
    
    return this_level_layer_groups
  end

  def get_bounds_from_layers
    layer_bounds = self.non_style_layers.collect { |layer| layer.bounds }
    layer_group_bounds = self.layer_groups.collect {|group| group.bounds }
    
    groupable_bounds = layer_bounds + layer_group_bounds

    if self.layer_groups.size == 1
      layer_group_key = Utils::get_group_key_from_layers self.layer_groups.first.layers 
      layers_key = Utils::get_group_key_from_layers self.non_style_layers
      
      if layers_key == layer_group_key
        groupable_bounds = layer_bounds
      end
    end

    return groupable_bounds
  end

  def bounds
    self.content[:bounds]
  end

  def orientation
    self.content[:orientation]
  end

  def has_alternate_grouping
    return self.content.fetch :has_alternate_grouping, false
  end

  def has_intersecting_layers
    return self.content.fetch :has_intersecting_layers, false
  end

  def enable_alternate_grouping
    return self.content.fetch :enable_alternate_grouping, false
  end

  def non_style_layers
    self.layers - self.style_layers
  end

  def style_layers
    return [] if self.is_leaf? and self.layers.size == 1

    all_layers_bounds = self.layers.collect {|layer| layer.bounds}
    layers_superbound = BoundingBox.get_super_bounds all_layers_bounds

    style_layers = self.layers.select do |layer|
      layer.bounds == layers_superbound
    end

    style_layers
  end

  def css_class_name
    return nil
  end

  def get_layers_in_region(region_bounds)
    layers_in_region = self.layers.select do |layer|
      region_bounds.encloses? layer.bounds
    end

    layers_in_region
  end

  def groupify
    # All layer boundaries to get the gutters
    bounding_boxes = self.get_bounds_from_layers

    # Get the vertical and horizontal gutters at this level
    vertical_gutters   = GroupingBox.get_vertical_gutters bounding_boxes
    horizontal_gutters = GroupingBox.get_horizontal_gutters bounding_boxes
    Log.debug "Vertical Gutters: #{vertical_gutters}"
    Log.debug "Horizontal Gutters: #{horizontal_gutters}"

    # if empty gutters, then there probably is no children here.
    # TODO: Find out if this even happens?
    if vertical_gutters.empty? or horizontal_gutters.empty?
      return
    end
    
    trailing_horizontal_gutters = horizontal_gutters
    leading_horizontal_gutters  = horizontal_gutters.rotate

    trailing_vertical_gutters = vertical_gutters
    leading_vertical_gutters  = vertical_gutters.rotate

    horizontal_bounds = trailing_horizontal_gutters.zip leading_horizontal_gutters
    vertical_bounds   = trailing_vertical_gutters.zip leading_vertical_gutters

    horizontal_bounds.pop
    vertical_bounds.pop

    # should i go normal orientation or left orientation
    # there are 4 cases:
    # 0. there are exactly 2 vertical gutters and 2 horizontal gutters. Things are intersecting. No more grouping
    # 1. there are exactly 2 vertical gutters - which means all divs are in GRID_ORIENT_NORMAL. only row grids
    # 2. there are exactly 2 horizontal gutters - which means all divs are in GRID_ORIENT_LEFT. only colum grids
    # 3. there are multiple vertical and horizontal gutters. This has two scenarios
    # => 3a. the grids are to be grouped first by horizontal gutters
    # => 3b. the grids are to be grouped first by vertical gutters
    
    if vertical_bounds.size == 1 and horizontal_bounds.size == 1
      self.content[:orientation] = Constants::GRID_ORIENT_NORMAL
      # case 0
      if self.layers.size > 1 
        self.content[:has_intersecting_layers] = true
      end
      return

    elsif vertical_bounds.size == 1 
      # case 1
      vertical_bound = vertical_bounds.first
      self.content[:orientation] = Constants::GRID_ORIENT_NORMAL
      horizontal_bounds.each do |horizontal_bound|
        grouping_box_bounds = BoundingBox.create_from_bounds horizontal_bound, vertical_bound
        grouping_box_layers = self.get_layers_in_region grouping_box_bounds
        child_grouping_box = GroupingBox.new :layers => grouping_box_layers, :bounds => grouping_box_bounds, :design => @design

        self.add child_grouping_box
      end
    elsif horizontal_bounds.size == 1 
      # case 2
      horizontal_bound = horizontal_bounds.first
      self.content[:orientation] = Constants::GRID_ORIENT_LEFT
      vertical_bounds.each do |vertical_bound|
        grouping_box_bounds = BoundingBox.create_from_bounds horizontal_bound, vertical_bound
        grouping_box_layers = self.get_layers_in_region grouping_box_bounds
        child_grouping_box = GroupingBox.new :layers => grouping_box_layers, :bounds => grouping_box_bounds, :design => @design
        self.add child_grouping_box
      end
      
    else
      # case 3
      self.content[:has_alternate_grouping] = true

      if not self.enable_alternate_grouping
        # case 3a
        vertical_bound = [vertical_gutters.first, vertical_gutters.last]
        self.content[:orientation] = Constants::GRID_ORIENT_NORMAL
        horizontal_bounds.each do |horizontal_bound|
          grouping_box_bounds = BoundingBox.create_from_bounds horizontal_bound, vertical_bound
          grouping_box_layers = self.get_layers_in_region grouping_box_bounds
          child_grouping_box = GroupingBox.new :layers => grouping_box_layers, :bounds => grouping_box_bounds, :design => @design
          self.add child_grouping_box
        end
      else
        # case 3b
        horizontal_bound = [horizontal_gutters.first, horizontal_gutters.last]
        self.content[:orientation] = Constants::GRID_ORIENT_LEFT
        vertical_bounds.each do |vertical_bound|
          grouping_box_bounds = BoundingBox.create_from_bounds horizontal_bound, vertical_bound
          grouping_box_layers = self.get_layers_in_region grouping_box_bounds
          child_grouping_box = GroupingBox.new :layers => grouping_box_layers, :bounds => grouping_box_bounds, :design => @design
          self.add child_grouping_box
        end
      end
    end
    
    self.children.each do |child|
      if not child.layers.empty?
        child.groupify
      end
    end
  end

  def add_to_offset_box(bounding_box)
    new_offset_box = nil
    if self.offset_box.nil?
      new_offset_box = bounding_box
    else 
      new_offset_box = BoundingBox.get_super_bounds [bounding_box, self.offset_box]
    end
    
    self.content[:grid_offset_box] = new_offset_box
  end

  def reset_offset_box
    self.content[:grid_offset_box] = nil
  end
  
  def offset_box
    self.content[:grid_offset_box]
  end

  def create_grid
    # If there are no layers in this grouping box, then this is an offset box
    return nil if self.layers.empty?

    # A grid is possible here. 
    grid = Grid.new :layers => self.layers, 
      :bounds => self.bounds, 
      :orientation => self.orientation, 
      :grouping_box => self,
      :style_layers => self.style_layers,
      :design => @design


    self.style_layers.each do |layer|
      layer.style_layer = true
    end

    # For each child to this grouping box, recursively get its grid and add as child to this grid
    self.children.each do |child_grouping_box|
      child_grid = child_grouping_box.create_grid
      
      if child_grid.nil?
        # This means the child is an offset box, so add this grouping box as offset box
        self.add_to_offset_box child_grouping_box.bounds
      else
        # The child grid exists. If there is an non empty offset box, then add it to this grid
        if not self.offset_box.nil?
          child_grid.offset_box = self.offset_box
          self.reset_offset_box
        end
        
        grid.add child_grid
      end
    end

    return grid
  end

  def print_tree(level = 0)
    if is_root?
      print "*"
    else
      print "|" unless parent.is_last_sibling?
      print(' ' * (level - 1) * 4)
      print(is_last_sibling? ? "+" : "|")
      print "---"
      print(has_children? ? "+" : ">")
    end

    puts "#{self.to_s}"

    children { |child| child.print_tree(level + 1)}
  end
end