class PreProcessorJob
  @queue = :pre_processor
  def self.perform(design_id)
    design = Design.find design_id
    
    Log.info "Pre processing #{design.name}..."
    
    photoshop_file  = Store.fetch_object_from_store design.psd_file_path
    psd_file_root   = File.basename design.psd_file_path, '.psd'
    screenshot_file = Rails.root.join 'tmp', 'store', design.store_key_prefix, "#{psd_file_root}.png"
    thumbnail_file  = Rails.root.join 'tmp', 'store', design.store_key_prefix, "#{psd_file_root}-thumbnail.png"
    
    screenshot_cmd = "convert #{photoshop_file} -flatten #{screenshot_file}"
    thumbnail_cmd  = "convert #{screenshot_file} -thumbnail 240x180 -unsharp 0x.8 #{thumbnail_file}"
    
    Log.info screenshot_cmd
    system screenshot_cmd
    
    Log.info thumbnail_cmd
    system thumbnail_cmd
    
    Store.save_to_store screenshot_file, File.join(design.store_processed_key, "#{psd_file_root}.png")
    Store.save_to_store thumbnail_file, File.join(design.store_processed_key, "#{psd_file_root}-thumbnail.png")
    
    Log.info "Sucessfully completed pre processing of #{design.name}."
  end
end