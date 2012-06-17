class MarkupGeneratorJob
  @queue = :generator
  
  def self.perform(design_id)
    design = Design.find design_id

    # Set design back to generating
    design.set_status Design::STATUS_GENERATING
    
    # Fetch the processed files once again
    Store::fetch_from_store design.store_processed_key

    # Generate markup once in publishable mode once
    design.generate_markup false
    
    # Generate markup once in editable mode once
    design.generate_markup true

    # mark editing complete
    design.set_status Design::STATUS_COMPLETED
  end
end