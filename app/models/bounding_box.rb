class BoundingBox
  attr_accessor :top, :left, :bottom, :right
  attr_reader :width, :height

  def initialize(top=nil, left=nil, bottom=nil, right=nil)
    set(top, left, bottom, right)
  end

  def reset
    set(nil, nil, nil, nil)
  end

  def set(top, left, bottom, right)
    self.top = top
    self.left = left
    self.bottom = bottom
    self.right = right

    begin
      @width = (right-left).abs
      @height = (bottom-top).abs
    rescue
      @width = nil
      @height = nil
    end
  end

  def to_s
    "(#{self.top}, #{self.left}, #{self.bottom}, #{self.right})"
  end

  def same_as?(other_box)
    self.top == other_box.top and self.left == other_box.left and self.bottom == other_box.bottom and self.right == other_box.right
  end

  def encloses?(other_box)
    self.top <= other_box.top and self.bottom >= other_box.bottom and self.left <= other_box.left and self.right >= other_box.right
  end

  def overlaps?(other_box)
    left_distance = (self.left-other_box.left).abs
    top_distance = (self.top - other_box.top).abs
    return ((left_distance < self.width or left_distance < other_box.width) and (top_distance < self.height or top_distance < other_box.height))
  end

  #Super bound is the minimal bounding box that encloses a bunch of bounding boxes
  def self.get_super_bounds(bounding_box_list)
    top = left = bottom = right = nil
    bounding_box_list.each do |bounding_box|
      if top.nil? or bounding_box.top<top
        top = bounding_box.top
      end
      if left.nil? or bounding_box.left<left
        left = bounding_box.left
      end
      if bottom.nil? or bounding_box.bottom>bottom
        bottom = bounding_box.bottom
      end
      if right.nil? or bounding_box.right>right
        right = bounding_box.right
      end
    end
    return BoundingBox.new(top, left, bottom , right)
  end

  def self.get_objects_in_region(region, objects, bound_getter_name)
    puts "+++++++++++++++++++++++++++"
    puts "Region considered: #{region}"
    puts "Objects considered: #{objects}"
    objects_in_region = objects.select do |item|
      bounds = item.send(bound_getter_name)
      puts "-- #{item} -- #{region.encloses?(bounds)}"
      region.encloses?(bounds)
    end
    puts "Objects in region: #{objects_in_region}"
    puts "+++++++++++++++++++++++++++"
    return objects_in_region
  end
end
