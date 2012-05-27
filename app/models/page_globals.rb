class PageGlobals
  @@instance = nil
  attr_accessor :grouping_queue, :padding_prefix_buffer, :page_bounds, :padding_boxes

  private
  def initialize
    self.grouping_queue = Queue.new
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
  
end