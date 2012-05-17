class PageGlobals
  @@instance = nil
  attr_accessor :grouping_queue, :page_bounds
  private
  def initialize
    self.grouping_queue = Queue.new
  end
  
  public
  def self.instance
    if @@instance.nil?
      @@instance = self.new()
    end
    return @@instance
  end
end