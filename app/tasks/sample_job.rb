class SampleJob
  extend Resque::Plugins::History

  @queue = :uploader

  def self.perform(design_id)
    design = Design.find design_id
    
    src_dir = File.join "sample_designs", design.safe_name_prefix
    destination_dir = design.store_key_prefix

    Store::copy_within_store_recursively src_dir, destination_dir
  
    design.status = Design::STATUS_EXTRACTING_DONE
    design.photoshop_status = Design::STATUS_PROCESSING_DONE
    design.save!
  end
end