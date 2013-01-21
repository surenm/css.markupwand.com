require 'open3'
class ExtractorJob
  extend Resque::Plugins::History
  
  @queue = :worker
  
  def self.perform(design_id)
    design = Design.find design_id
    design.set_status Design::STATUS_EXTRACTING

    Log.info "Extracting design data from photoshop file #{design.name}..."
    
    design_folder  = Store.fetch_from_store design.store_key_prefix
    photoshop_file = Rails.root.join 'tmp', 'store', design.psd_file_path
    psd_file_root  = File.basename design.psd_file_path, '.psd'
    
    extracted_folder = Rails.root.join 'tmp', 'store', design.store_extracted_key
    assets_folder = File.join extracted_folder, "assets"
    images_folder = File.join extracted_folder, "assets", "images"
    FileUtils.mkdir_p images_folder if not Dir.exists? images_folder

    extracted_file   = Rails.root.join extracted_folder, "#{design.safe_name_prefix}.json"
    screenshot_file  = Rails.root.join extracted_folder, "#{design.safe_name_prefix}.png"
    fixed_width_file = Rails.root.join extracted_folder, "#{design.safe_name_prefix}-fixed.png"
    thumbnail_file   = Rails.root.join extracted_folder, "#{design.safe_name_prefix}-thumbnail.png"
    
    psdjs_root_dir   = Rails.root.join 'lib', 'psd.js'
    extractor_script = File.join psdjs_root_dir, 'tasks', 'extract.coffee'

    coffee_script_exe = Rails.root.join 'lib', 'psd.js', 'node_modules', '.bin', 'coffee'
    
    extractor_command = "#{coffee_script_exe} #{extractor_script} #{photoshop_file} #{extracted_folder} #{design.safe_name_prefix}"

    Log.info extractor_command
    err = nil
    Open3.popen3 extractor_command do |stdin, stdout, stderr|
      err = stderr.read
    end
    
    # If non nil stderr, then extraction has failed most probably
    if not err.nil? and not err.empty?
      Log.fatal "Extraction of design failed: #{err}"
      design.set_status Design::STATUS_FAILED
      design.add_tag Design::ERROR_EXTRACTION_FAILED
      design.save!
      raise err
    end
  
    # Build screenshot, thumbnail files
    fixed_width_cmd = "convert #{screenshot_file} -thumbnail '600x480>' -unsharp 0x.8 #{fixed_width_file}"
    thumbnail_cmd   = "convert #{screenshot_file} -thumbnail '180x240>' -unsharp 0x.8 #{thumbnail_file}"
    
    Log.info fixed_width_cmd
    system fixed_width_cmd
    
    Log.info thumbnail_cmd
    system thumbnail_cmd
    
    Store.save_to_store extracted_file, File.join(design.store_extracted_key, "#{design.safe_name_prefix}.json")
    Store.save_to_store screenshot_file, File.join(design.store_extracted_key, "#{design.safe_name_prefix}.png")
    Store.save_to_store fixed_width_file, File.join(design.store_extracted_key, "#{design.safe_name_prefix}-fixed.png")
    Store.save_to_store thumbnail_file, File.join(design.store_extracted_key, "#{design.safe_name_prefix}-thumbnail.png")

    
    Dir.glob("#{assets_folder}/**/*").each do |asset_file_path|
      next if File.directory? asset_file_path
      asset_file_path_obj = Pathname.new asset_file_path
      asset_relative_path = asset_file_path_obj.relative_path_from(Pathname.new assets_folder)
      asset_destination_path = File.join design.store_extracted_key, "assets", asset_relative_path
      Store.save_to_store(asset_file_path, asset_destination_path)
    end
    design.set_status Design::STATUS_EXTRACTING_DONE
    Log.info "Sucessfully completed extracting from photoshop file #{design.name}."

    # Build sif file from extracted file    
    Log.info "Building SIF File from extracted file..."
    SifBuilder.build_from_extracted_file design, extracted_file
    Log.info "Successfully built SIF file."

    if design.photoshop_status != Design::STATUS_PROCESSING_DONE
      design.push_to_images_queue
    end
  end
end
