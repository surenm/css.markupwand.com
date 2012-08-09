class ScreenshotJob
  @queue = :screenshot
  
  def self.perform(design_item)
    design_id = design_item.strip.split('-').last
    design = Design.find design_id
    
    Log.info "Generating screenshots and thumbnails for #{design.name}..."
    
    design_folder  = Store.fetch_from_store design.store_key_prefix
    photoshop_file = design.psd_file_path
    psd_file_root  = File.basename design.psd_file_path, '.psd'
    
    screenshot_file  = Rails.root.join 'tmp', 'store', design.store_psdjsprocessed_key, "output.png"
    fixed_width_file = Rails.root.join 'tmp', 'store', design.store_key_prefix, "#{psd_file_root}-fixed.png"
    thumbnail_file   = Rails.root.join 'tmp', 'store', design.store_key_prefix, "#{psd_file_root}-thumbnail.png"
    
    fixed_width_cmd = "convert #{screenshot_file} -thumbnail '600x480>' -unsharp 0x.8 #{fixed_width_file}"
    thumbnail_cmd   = "convert #{screenshot_file} -thumbnail '180x240>' -unsharp 0x.8 #{thumbnail_file}"
    
    Log.info fixed_width_cmd
    system fixed_width_cmd
    
    Log.info thumbnail_cmd
    system thumbnail_cmd
    
    Store.save_to_store screenshot_file, File.join(design.store_processed_key, "#{psd_file_root}.png")
    Store.save_to_store fixed_width_file, File.join(design.store_processed_key, "#{psd_file_root}-fixed.png")
    Store.save_to_store thumbnail_file, File.join(design.store_processed_key, "#{psd_file_root}-thumbnail.png")
    
    design.pre_processed = true
    design.save!
  
    Log.info "Sucessfully completed pre processing of #{design.name}."

  end
end