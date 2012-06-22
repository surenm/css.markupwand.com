require 'log4r'
include Log4r

module Log
  LOGGER = Log4r::Logger.new 'logger'
  LOGGER.outputters = Log4r::FileOutputter.new 'debugger', :filename => File.join(Rails.root, "log", "#{Rails.env}-debug.log")
  LOGGER.add Log4r::StdoutOutputter.new 'console'
  if Rails.env.development?
    LOGGER.level = Log4r::DEBUG
  else 
    LOGGER.level = Log4r::INFO
  end
  
  def Log.method_missing(method, *args, &block)
    LOGGER.send method, args[0]
    return
  end
  
  def Log.level(level)
    LOGGER.level = level
  end
end