class BoundingBox
  attr_accessor :top, :left, :bottom, :right
  attr_reader :width, :height, :area

  private
  def set_derived_dimensions
    begin
      @width = (self.right-self.left).abs
      @height = (self.bottom-self.top).abs
      @area = @width * @height
    rescue
      @width = nil
      @height = nil
      @area = nil
    end
  end

  public
  def initialize(top=nil, left=nil, bottom=nil, right=nil)
    set(top, left, bottom, right)
    set_derived_dimensions
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

  def left=(left)
    @left = left
    set_derived_dimensions
  end

  def right=(right)
    @right = right
    set_derived_dimensions
  end

  def top=(top)
    @top = top
    set_derived_dimensions
  end

  def bottom=(bottom)
    @bottom = bottom
    set_derived_dimensions
  end

  def to_s
    "(#{self.top}, #{self.left}, #{self.bottom}, #{self.right})"
  end

  def crop_to(other_box)
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
    width  = [0, [self.right, other.right].min - [self.left, other.left].max].max
    Log.info "Width = #{width}"
    height = [0, [self.bottom, other.bottom].min - [self.top, other.top].max ].max
    Log.info "Height = #{height}"
    
    width*height
  end

  def encloses?(other_box)
    self.top <= other_box.top and self.bottom >= other_box.bottom and self.left <= other_box.left and self.right >= other_box.right
  end

  def overlaps?(other_box)
    left_distance = (self.left-other_box.left).abs
    top_distance = (self.top - other_box.top).abs
    return ((left_distance < self.width or left_distance < other_box.width) and (top_distance < self.height or top_distance < other_box.height))
  end

  def serialize
    [top, left, bottom, right]
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


  def self.get_objects_in_region(region, objects, bound_getter_name)

    Log.info "Checking if objects #{objects} are in region #{region}"
    objects_in_region = objects.select do |item|
      bounds = item.send(bound_getter_name)
      region.encloses? bounds
    end

    Log.info "#{objects_in_region} are within #{region}"

    return objects_in_region
  end

  def self.from_mongo(serialized_box)
    if not serialized_box.empty? 
      return BoundingBox.new(serialized_box[0], serialized_box[1],
        serialized_box[2], serialized_box[3])
    else
      return nil
    end
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
        end
      end
      horizontal_gutters.push horizontal_line if is_gutter
    end
    horizontal_gutters.sort!
  end
  
  def self.get_grouping_boxes(layers)

    # All layer boundaries to get the gutters
    bounding_boxes = layers.collect {|layer| layer.bounds}

    # Get the vertical and horizontal gutters at this level
    vertical_gutters   = BoundingBox.get_vertical_gutters bounding_boxes
    horizontal_gutters = BoundingBox.get_horizontal_gutters bounding_boxes
    Log.debug "Vertical Gutters: #{vertical_gutters}"
    Log.debug "Horizontal Gutters: #{horizontal_gutters}"

    # if empty gutters, then there probably is no children here.
    # TODO: Find out if this even happens?
    if vertical_gutters.empty? or horizontal_gutters.empty?
      return []
    end

    # get all possible grouping boxes with the available gutters
    grouping_boxes = []

    trailing_horizontal_gutters = horizontal_gutters
    leading_horizontal_gutters  = horizontal_gutters.rotate

    trailing_vertical_gutters = vertical_gutters
    leading_vertical_gutters  = vertical_gutters.rotate

    horizontal_bounds = trailing_horizontal_gutters.zip leading_horizontal_gutters
    vertical_bounds   = trailing_vertical_gutters.zip leading_vertical_gutters

    horizontal_bounds.pop
    vertical_bounds.pop

    root_group = Group.new Constants::GRID_ORIENT_NORMAL
    horizontal_bounds.each do |horizontal_bound|
      row_group = Group.new Constants::GRID_ORIENT_LEFT
      vertical_bounds.each do |vertical_bound|
        row_group.push BoundingBox.new horizontal_bound[0], vertical_bound[0], horizontal_bound[1], vertical_bound[1]
      end
      root_group.push row_group
    end

    Log.debug root_group
    return root_group
  end
  
end
