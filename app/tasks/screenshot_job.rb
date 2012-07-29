class ScreenshotJob
  @queue = :screenshot
  
  def self.perform(message)
  	Log.info "Dummy job done"
    # Dummy method so that queuing from web to this queue is possible. 
    # Check transformers project for the same class
  end
end