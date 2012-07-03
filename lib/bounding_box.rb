class BoundingBox
  attr_accessor :top, :left, :bottom, :right
  
  public
  def initialize(top=nil, left=nil, bottom=nil, right=nil)
    set(top, left, bottom, right)
  end

  def self.create_from_bounds(horizontal_bound, vertical_bound)
    BoundingBox.new horizontal_bound[0], vertical_bound[0], horizontal_bound[1], vertical_bound[1]
  end

  def reset
    set(nil, nil, nil, nil)
  end

  def nil?
    self.top.nil? or self.right.nil? or self.bottom.nil? or self.left.nil?
  end

  def set(top, left, bottom, right)
    self.top = top
    self.left = left
    self.bottom = bottom
    self.right = right
  end
  
  def width
    if self.right.nil? or self.left.nil?
      return nil
    else
      return (self.right-self.left).abs
    end
  end
  
  def height
    if self.bottom.nil? or self.top.nil?
      return nil
    else
      return (self.bottom-self.top).abs
    end
  end
  
  def area
    if self.width.nil? or self.right.nil?
      return nil
    else 
      return self.width * self.height
    end
  end

  def to_s
    "(#{self.top}, #{self.left}, #{self.bottom}, #{self.right})"
  end

  def inner_crop(other_box)
    cropped_bounds = self.class.new(self.top, self.left, self.bottom, self.right)

    if cropped_bounds.left > other_box.right or cropped_bounds.top > other_box.bottom
      return nil
    end

    if cropped_bounds.left < other_box.left
      cropped_bounds.left = other_box.left
    end

    if cropped_bounds.right > other_box.right
      cropped_bounds.right = other_box.right
    end

    if cropped_bounds.top < other_box.top
      cropped_bounds.top = other_box.top
    end

    if cropped_bounds.bottom > other_box.bottom
      cropped_bounds.bottom = other_box.bottom
    end

    return cropped_bounds
  end
  
  def vertical_crop(other_box)
    cropped_bounds = self.class.new(self.top, self.left, self.bottom, self.right)

    if other_box.left < cropped_bounds.left and cropped_bounds.left < other_box.right
      # Left edge intersecting
      cropped_bounds.left = other_box.right
    elsif other_box.left < cropped_bounds.right and cropped_bounds.right < other_box.right
      # Right edge intersecting
      cropped_bounds.right = other_box.left
    end

    cropped_bounds
  end
  
  def horizontal_crop(other_box)
    cropped_bounds = self.class.new(self.top, self.left, self.bottom, self.right)

    if other_box.top < cropped_bounds.top and cropped_bounds.top < other_box.bottom
      # Top edge is intersecting
      cropped_bounds.top = other_box.bottom

    elsif other_box.top < cropped_bounds.bottom and cropped_bounds.bottom < other_box.bottom
      # Bottom edge is interesecting

      cropped_bounds.bottom = other_box.top
    end

    cropped_bounds
  end
  
  def outer_crop(other_box)
    intersect_bounds_value = intersect_bounds(other_box)
    
    if intersect_bounds_value.height < intersect_bounds_value.width
      #Horizontal crop
      return horizontal_crop(other_box)
    else
      #Vertical crop
      return vertical_crop(other_box)
    end
  end

  def ==(other_box)
    self.top == other_box.top and self.left == other_box.left and self.bottom == other_box.bottom and self.right == other_box.right
  end

  def <=>(other_box)
    if self.top == other_box.top
      return self.left <=> other_box.left
    else
      return self.top <=> other_box.top
    end
  end

  def intersect?(other)
    self.left < other.right and self.right > other.left and self.top < other.bottom and self.bottom > other.top
  end
  
  def intersect_area(other)
    intersect_bounds(other).area
  end
  
  def intersect_bounds(other)
    right    = [self.right, other.right].min
    left     = [self.left, other.left].max
    bottom   = [self.bottom, other.bottom].min
    top      = [self.top, other.top].max
    
    self.class.new(top, left, bottom, right)
  end

  def encloses?(other_box)
    self.top <= other_box.top and self.bottom >= other_box.bottom and self.left <= other_box.left and self.right >= other_box.right
  end

  def overlaps?(other_box)
    left_distance = (self.left-other_box.left).abs
    top_distance = (self.top - other_box.top).abs
    return ((left_distance < self.width or left_distance < other_box.width) and (top_distance < self.height or top_distance < other_box.height))
  end

  def self.pickle(bounding_box)
    attribute_data = {
      :top    => bounding_box.top,
      :bottom => bounding_box.bottom,
      :left   => bounding_box.left,
      :right  => bounding_box.right
    }
    return attribute_data.to_json.to_s if not self.nil?  
  end
  
  def self.depickle(serialized_bounding_box)
    if not serialized_bounding_box.nil? and not serialized_bounding_box.empty? 
      data = JSON.parse serialized_bounding_box
      return BoundingBox.new data["top"], data["left"], data["bottom"], data["right"]
    end
  end
    
  #Super bound is the minimal bounding box that encloses a bunch of bounding boxes
  def self.get_super_bounds(bounding_box_list)
    top = left = bottom = right = nil
    bounding_box_list.each do |bounding_box|
      if top.nil? or bounding_box.top < top
        top = bounding_box.top
      end
      if left.nil? or bounding_box.left < left
        left = bounding_box.left
      end
      if bottom.nil? or bounding_box.bottom > bottom
        bottom = bounding_box.bottom
      end
      if right.nil? or bounding_box.right > right
        right = bounding_box.right
      end
    end
    return BoundingBox.new top, left, bottom, right
  end


  def self.get_nodes_in_region(region, objects, zindex = nil)

    Log.info "Checking if objects #{objects} are in region #{region}"
    objects_in_region = objects.select do |item|
      if item.kind_of? Layer
        region.encloses? item.bounds and item.zindex >= zindex.to_i 
      else 
        region.encloses? item
      end
    end

    Log.info "#{objects_in_region} are within #{region}"

    return objects_in_region
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
  
  def self.grouping_boxes_possible?(bounding_boxes)
    v_gutters = BoundingBox.get_vertical_gutters bounding_boxes
    h_gutters = BoundingBox.get_horizontal_gutters bounding_boxes
    return (v_gutters.size > 2 or h_gutters.size > 2)
  end
  
  def self.get_gutter_widths(bounding_boxes, gutter_bounds, gutter_type)
    gutter_widths = []
    gutter_bounds.each do |bound|
      is_gutter_bound = true
      bounding_boxes.each do |bounding_box|
        if gutter_type == :horizontal
          current_bound = [bounding_box.top, bounding_box.bottom]
        elsif gutter_type == :vertical
          current_bound = [bounding_box.left, bounding_box.right]
        end
        if not (current_bound.first < bound.first and current_bound.last <= bound.first) and
           not (current_bound.first >= bound.last and current_bound.last > bound.last)
          is_gutter_bound = false
          break
        end
      end
      gutter_widths.push (bound[1] - bound[0]) if is_gutter_bound
    end
    gutter_widths
  end
  
  def self.get_grouping_boxes(layers)

    # All layer boundaries to get the gutters
    bounding_boxes = layers.collect {|layer| layer.bounds}

    # Get the vertical and horizontal gutters at this level
    vertical_gutters   = BoundingBox.get_vertical_gutters bounding_boxes
    horizontal_gutters = BoundingBox.get_horizontal_gutters bounding_boxes
    Log.info "Vertical Gutters: #{vertical_gutters}"
    Log.info "Horizontal Gutters: #{horizontal_gutters}"

    # if empty gutters, then there probably is no children here.
    # TODO: Find out if this even happens?
    if vertical_gutters.empty? or horizontal_gutters.empty?
      return []
    end
    
    root_group = nil

    trailing_horizontal_gutters = horizontal_gutters
    leading_horizontal_gutters  = horizontal_gutters.rotate

    trailing_vertical_gutters = vertical_gutters
    leading_vertical_gutters  = vertical_gutters.rotate

    horizontal_bounds = trailing_horizontal_gutters.zip leading_horizontal_gutters
    vertical_bounds   = trailing_vertical_gutters.zip leading_vertical_gutters

    horizontal_bounds.pop
    vertical_bounds.pop

    # should i go normal orientation or left orientation
    # there are 3 cases:
    # 1. there are only 2 vertical gutters - which means all divs are in GRID_ORIENT_NORMAL. only row grids
    # 2. there are only 2 horizontal gutters - which means all divs are in GRID_ORIENT_LEFT. only colum grids
    # 3. there are multiple vertical and horizontal gutters. This has two scenarios
    # => 3a. the grids are to be grouped first by horizontal gutters
    # => 3b. the grids are to be grouped first by vertical gutters
    # 3a and 3b are decided by the largest gutter size.
    
    if vertical_bounds.size == 1 
      # case 1
      root_group = GroupingBox.new Constants::GRID_ORIENT_NORMAL
      vertical_bound = vertical_bounds.first
      horizontal_bounds.each do |horizontal_bound|
        root_group.push BoundingBox.create_from_bounds horizontal_bound, vertical_bound
      end
    elsif horizontal_bounds.size == 1 
      # case 2
      root_group = GroupingBox.new Constants::GRID_ORIENT_LEFT
      horizontal_bound = horizontal_bounds.first
      vertical_bounds.each do |vertical_bound|
        root_group.push BoundingBox.create_from_bounds horizontal_bound, vertical_bound
      end
    else
      # case 3
      # TODO: figure out if normal first of left first orientation
      #h_gutter_widths = BoundingBox.get_gutter_widths bounding_boxes, horizontal_bounds, :horizontal
      #v_gutter_widths = BoundingBox.get_gutter_widths bounding_boxes, vertical_bounds, :vertical
  
      #case 3a
      root_group = GroupingBox.new Constants::GRID_ORIENT_NORMAL
      horizontal_bounds.each do |horizontal_bound|
        row_group = GroupingBox.new Constants::GRID_ORIENT_LEFT
        vertical_bounds.each do |vertical_bound|
          row_group.push BoundingBox.create_from_bounds horizontal_bound, vertical_bound
        end
        root_group.push row_group
      end

    end
    return root_group
  end
  
end
