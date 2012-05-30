class PageGlobals
  @@instance = nil
  attr_accessor :padding_prefix_buffer, :page_bounds, :padding_boxes

  private
  def initialize
    self.padding_boxes  = []
  end
  
  public
  def self.instance
    if @@instance.nil?
      @@instance = self.new()
    end
    return @@instance
  end
  
  def reset_padding_prefix
    self.padding_prefix_buffer = nil
  end
  
  def add_padding_box(padding_box)
    @@instance.padding_prefix_buffer = padding_box
    @@instance.padding_boxes.push padding_box
    @@instance.padding_boxes.uniq!
  end
  
end