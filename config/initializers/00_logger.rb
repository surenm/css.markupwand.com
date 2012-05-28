require 'log4r'
include Log4r

module Log
  LOGGER = Log4r::Logger.new 'logger'
  LOGGER.outputters = Log4r::FileOutputter.new 'debugger', :filename => File.join(Rails.root, "log", "#{Rails.env}-debug.log")
  if Rails.env == "development"
    LOGGER.add ColorOutputter.new 'color', {:colors => 
      { 
        :debug  => :light_blue, 
        :info   => :green, 
        :warn   => :yellow, 
        :error  => :red, 
        :fatal  => {:color => :red, :background => :white} 
      } 
    }
  end
  
  def Log.method_missing(method, *args, &block)
    LOGGER.send method, args[0]
    return
  end
  
  def Log.level(level)
    LOGGER.level = level
  end
end