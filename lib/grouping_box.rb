class GroupingBox
  attr_accessor :orientation, :children

  # orientation could be :normal, :left, :right
  def initialize(orientation)
    @orientation = orientation
    @children = []
  end
  
  def push(child)
    @children.push child
  end
  
  def to_s
    "#{@orientation} - #{@children}"
  end
  
  def bounds
    bounding_boxes = []
    @children.each do |child| 
      if child.kind_of? BoundingBox
        bounding_boxes.push child
      elsif child.kind_of? GroupingBox
        bounding_boxes.push child.bounds
      end
    end
    BoundingBox.get_super_bounds bounding_boxes
  end
end