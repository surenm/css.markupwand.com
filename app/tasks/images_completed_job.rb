class ImagesCompletedJob
  extend Resque::Plugins::History
  @queue = :worker

  def self.perform(design_id)
    design = Design.find design_id
    user = design.user
    src_folder = design.store_images_key
    destination_folder = File.join design.store_extracted_key, "images"
    if Dir.exists? destination_folder
      Store::copy_within_store_recursively src_folder, destination_folder
    end

    design.photoshop_status = Design::STATUS_PROCESSING_DONE
    design.save!
    Resque.enqueue ChatNotifyJob, "#{user.name.to_s} (#{user.email.to_s})'s images are completed"
  end
end