class DesignNode
  attr_accessor :bounds, :name
  def initialize(bounds, name)
    self.bounds = bounds
    self.name   = name
  end
  
  def to_s
    self.name+"--"+self.bounds.to_s
  end
end

