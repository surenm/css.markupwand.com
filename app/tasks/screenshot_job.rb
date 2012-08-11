class ScreenshotJob
  extend Resque::Plugins::History
  
  @queue = :screenshot
  
  def self.perform(design_id)
    design = Design.find design_id
    
    Log.info "Generating screenshots and thumbnails for #{design.name}..."
    
    design_folder  = Store.fetch_from_store design.store_key_prefix
    photoshop_file = Rails.root.join 'tmp', 'store', design.psd_file_path
    psd_file_root  = File.basename design.psd_file_path, '.psd'
    
    psdjsprocessed_directory = Rails.root.join 'tmp', 'store', design.store_psdjsprocessed_key
    FileUtils.mkdir psdjsprocessed_directory if not Dir.exists? psdjsprocessed_directory
    
    screenshot_file  = Rails.root.join 'tmp', 'store', design.store_psdjsprocessed_key, "#{psd_file_root}.png"
    fixed_width_file = Rails.root.join 'tmp', 'store', design.store_psdjsprocessed_key, "#{psd_file_root}-fixed.png"
    thumbnail_file   = Rails.root.join 'tmp', 'store', design.store_psdjsprocessed_key, "#{psd_file_root}-thumbnail.png"
    
    screenshot_script = Rails.root.join 'tmp', 'psdjs', 'screenshot.coffee'
    coffee_script = Rails.root.join 'tmp', 'psdjs', 'node_modules', '.bin', 'coffee'
    
    screenshot_cmd  = "#{coffee_script} #{screenshot_script} #{photoshop_file} #{screenshot_file}"
    fixed_width_cmd = "convert #{screenshot_file} -thumbnail '600x480>' -unsharp 0x.8 #{fixed_width_file}"
    thumbnail_cmd   = "convert #{screenshot_file} -thumbnail '180x240>' -unsharp 0x.8 #{thumbnail_file}"
    
    Log.info screenshot_cmd
    system screenshot_cmd
    
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