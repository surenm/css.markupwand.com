require 'log4r'
include Log4r

module Log
  LOGGER = Log4r::Logger.new 'logger'
  LOGGER.outputters = Log4r::StdoutOutputter.new 'console'
  LOGGER.level = Log4r::INFO
  
  def Log.method_missing(method, *args, &block)
    LOGGER.send method, args[0]
    return
  end
  
  def Log.level(level)
    LOGGER.level = level
  end
end