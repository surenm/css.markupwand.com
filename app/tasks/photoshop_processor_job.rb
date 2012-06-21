class PhotoshopProcessorJob
  @queue = :photoshop_processor
  
  def self.perform(message)
    # Dummy method so that queuing from web is possible. 
    # Check transformers project for the same class
  end
end