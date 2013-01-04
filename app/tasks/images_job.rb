class ImagesJob
  extend Resque::Plugins::History
  @queue = :processor
  
  def self.perform(message)
    # Dummy method so that queuing from web to this queue is possible. 
    # Check transformers project for the same class
  end
end