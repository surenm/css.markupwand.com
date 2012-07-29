class PriorityProcessorJob
  @queue = :priority_processor
  
  def self.perform(message)
    # Dummy method so that queuing from web to this queue is possible. 
    # Check transformers project for the same class
  end
end