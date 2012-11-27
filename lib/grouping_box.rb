class GroupingBox < Tree::TreeNode

  def self.get_bounds_from_layers(layers)
    bounds_list = layers.collect do |layer| layer.bounds end  
    bounds_list
  end

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
    root_node.breadth_each do |node|
      next if node[node_name].nil?
      return node[node_name]
    end
  end

  def initialize(args)
    bounds = args.fetch :bounds
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
      :id => self.unique_identifier,
      :bounds => self.bounds,
      :orientation => self.orientation,
      :layers => layer_keys,
      :children => children_tree,
      :alternate_grouping => self.content[:alternate_grouping_boxes],
      :has_intersecting_layers => self.content[:has_intersecting_layers]
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

  def bounds
    self.content[:bounds]
  end

  def orientation
    self.content[:orientation]
  end

  def non_style_layers
    all_layers = self.layers
    non_style_layers = all_layers.select do |layer|
      layer.bounds != self.bounds
    end
  end

  def style_layers
    all_layers = self.layers
    style_layers = all_layers.select do |layer|
      layer.bounds == self.bounds
    end
  end

  def get_layers_in_region(region_bounds)
    layers_in_region = self.layers.select do |layer|
      region_bounds.encloses? layer.bounds
    end

    layers_in_region
  end

  def groupify
    # All layer boundaries to get the gutters
    bounding_boxes = GroupingBox.get_bounds_from_layers self.non_style_layers

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
        child_grouping_box = GroupingBox.new :layers => grouping_box_layers, :bounds => grouping_box_bounds

        self.add child_grouping_box
      end
    elsif horizontal_bounds.size == 1 
      # case 2
      horizontal_bound = horizontal_bounds.first
      self.content[:orientation] = Constants::GRID_ORIENT_LEFT
      vertical_bounds.each do |vertical_bound|
        grouping_box_bounds = BoundingBox.create_from_bounds horizontal_bound, vertical_bound
        grouping_box_layers = self.get_layers_in_region grouping_box_bounds
        child_grouping_box = GroupingBox.new :layers => grouping_box_layers, :bounds => grouping_box_bounds
        self.add child_grouping_box
      end
      
    else
      # case 3
      # TODO: figure out if normal first of left first orientation
      #h_gutter_widths = BoundingBox.get_gutter_widths bounding_boxes, horizontal_bounds, :horizontal
      #v_gutter_widths = BoundingBox.get_gutter_widths bounding_boxes, vertical_bounds, :vertical
  
      # case 3a
      vertical_bound = [vertical_gutters.first, vertical_gutters.last]
      self.content[:orientation] = Constants::GRID_ORIENT_NORMAL
      horizontal_bounds.each do |horizontal_bound|
        grouping_box_bounds = BoundingBox.create_from_bounds horizontal_bound, vertical_bound
        grouping_box_layers = self.get_layers_in_region grouping_box_bounds
        child_grouping_box = GroupingBox.new :layers => grouping_box_layers, :bounds => grouping_box_bounds
        self.add child_grouping_box
      end

      # case 3b
      self.content[:alternate_grouping_boxes] = Array.new
      horizontal_bound = [horizontal_gutters.first, horizontal_gutters.last]

      vertical_bounds.each do |vertical_bound|
        grouping_box_bounds = BoundingBox.create_from_bounds horizontal_bound, vertical_bound
        grouping_box_layers = self.get_layers_in_region grouping_box_bounds
        self.content[:alternate_grouping_boxes].push grouping_box_bounds
      end
    end
    
    self.children.each do |child|
      if not child.layers.empty?
        child.groupify
      end
    end
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