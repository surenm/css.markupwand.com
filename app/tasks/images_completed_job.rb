class ImagesCompletedJob
  extend Resque::Plugins::History
  @queue = :worker

  def self.perform(design_id)
    design = Design.find design_id
    
    src_folder = design.store_images_key
    destination_folder = File.join design.store_extracted_key, "images"
    Store::copy_within_store_recursively src_folder, destination_folder

    design.photoshop_status = Design::STATUS_PROCESSING_DONE
    design.save!
  end
end