class PageGlobals
  @@instance = nil
  attr_accessor :padding_prefix_buffer, :page_bounds

  private
  def initialize
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
    self.padding_prefix_buffer = padding_box
  end
  
end