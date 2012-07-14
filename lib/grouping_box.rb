class GroupingBox
  attr_accessor :orientation, :children

  # orientation could be :normal, :left, :right
  def initialize(orientation)
    @orientation = orientation
    @bounding_box = nil
    @children = []
  end
  
  def push(child)
    @children.push child
  end
  
  def to_s
    "#{@orientation} - #{bounds} - #{@children}"
  end
  
  def bounds
    if @bounding_box.nil?
      bounding_boxes = []
      @children.each do |child| 
        if child.kind_of? BoundingBox
          bounding_boxes.push child
        elsif child.kind_of? GroupingBox
          bounding_boxes.push child.bounds
        end
      end
      @bounding_box = BoundingBox.get_super_bounds bounding_boxes
    end
    
    return @bounding_box
  end
  
  def bounds=(bounding_box)
    @bounding_box = bounding_box
  end
  
end