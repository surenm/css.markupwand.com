class MarkupParserJob
  @queue = :markup_parser
  
  def self.perform(design_id)
    design = Design.find design_id
    design.set_status Design::STATUS_GENERATING
    
    Store::fetch_from_store design.store_processed_key

    design_processed_directory = Rails.root.join 'tmp', 'store', design.store_processed_key
    Log.info "Design processed directory : #{design_processed_directory} "
    
    Dir["#{design_processed_directory}/*.psd.json"].each do |processed_file|
      Log.info "Found processed file - #{processed_file}"
      design.processed_file_path = processed_file
      design.save!
      break
    end
    
    design.parse
    
    # Generate markup for editing and publishing
    Resque.enqueue MarkupRegeneratorJob, design_id
      
    design.set_status Design::STATUS_COMPLETED
  end
end