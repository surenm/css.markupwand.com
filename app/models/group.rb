class Group
  attr_accessor :orientation, :children

  # orientation could be :normal, :left, :right
  def initialize(orientation)
    @orientation = orientation
    @children = []
  end
  
  def push(child)
    @children.push child
  end
end