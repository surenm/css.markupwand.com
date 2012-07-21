require 'log4r'
include Log4r

module Log
  LOGGER = Log4r::Logger.new 'logger'
  LOGGER.outputters = Log4r::StdoutOutputter.new 'console'
  if not ENV["LOG_LEVEL"].nil?
    LOGGER.level = Log4r.const_get ENV["LOG_LEVEL"]
  else 
    LOGGER.level = Log4r::INFO
  end
  
  def Log.method_missing(method, *args, &block)
    if Rails.env.development?
      LOGGER.send method, args[0].ai
    else 
      LOGGER.send method, args[0]
    end
    return
  end
  
  def Log.level(level)
    LOGGER.level = level
  end
end