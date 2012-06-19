class PageGlobals
  @@instance = nil
  attr_accessor :offset_box_buffer, :offset_box_list

  private
  def initialize
  end
  
  public
  def self.data_dir
    @@data_dir ||= ENV['DATADIR']
    @@data_dir ||= '/tmp'
    return @@data_dir
  end

  def self.data_dir=(dir)
    @@data_dir = dir
  end

  def self.instance
    if @@instance.nil?
      @@instance = self.new()
    end
    return @@instance
  end  
end