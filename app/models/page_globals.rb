class PageGlobals
  @@instance = nil
  attr_accessor :offset_box_buffer, :page_bounds, :offset_box_list

  private
  def initialize
    @offset_box_list = []
  end
  
  public
  def self.input_dir
    @@input_dir ||= ENV['INPUTDIR']
    @@input_dir ||= 'tmp'
    return @@input_dir
  end

  def self.instance
    if @@instance.nil?
      @@instance = self.new()
    end
    return @@instance
  end
  
  def reset_offset_buffer
    self.offset_box_buffer = nil
  end
  
  def add_offset_box(offset_box)
    self.offset_box_buffer = offset_box
    self.offset_box_list.push offset_box.clone
    self.offset_box_list.uniq!
  end
  
end