class MarkupGeneratorJob
  @queue = :generator
  
  def self.perform(design_id)
    design = Design.find design_id
    design.set_status Design::STATUS_GENERATING
    
    Store::fetch_from_store design.store_key_prefix

    design_processed_directory = Rails.root.join 'tmp', 'store', design.store_key_prefix, 'processed'
    Log.info design_processed_directory
    
    Dir["#{design_processed_directory}/*.psd.json"].each do |processed_file|
      Log.info "Found processed file - #{processed_file}"
      design.processed_file_path = processed_file
      design.save!
      break
    end
    
    design.parse
    design.generate_markup
    design.setstatus Design::STATUS_COMPLETED
  end
end