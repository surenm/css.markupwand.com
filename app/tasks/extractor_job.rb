require 'open3'
class ExtractorJob
  extend Resque::Plugins::History
  
  @queue = :extractor
  
  def self.perform(design_id)
    design = Design.find design_id
    design.save!

    design.set_status Design::STATUS_EXTRACTING

    Log.info "Extracting design data from photoshop file #{design.name}..."
    
    design_folder  = Store.fetch_from_store design.store_key_prefix
    photoshop_file = Rails.root.join 'tmp', 'store', design.psd_file_path
    psd_file_root  = File.basename design.psd_file_path, '.psd'
    
    processed_folder = Rails.root.join 'tmp', 'store', design.store_extracted_key
    assets_directory = Rails.root.join processed_folder, "assets"
    FileUtils.mkdir_p assets_directory if not Dir.exists? assets_directory
    
    processed_file   = Rails.root.join processed_folder, "#{design.safe_name_prefix}.json"
    screenshot_file  = Rails.root.join processed_folder, "#{design.safe_name_prefix}.png"
    fixed_width_file = Rails.root.join processed_folder, "#{design.safe_name_prefix}-fixed.png"
    thumbnail_file   = Rails.root.join processed_folder, "#{design.safe_name_prefix}-thumbnail.png"
    clipping_layer_check_file = Rails.root.join processed_folder, "has_clipping_layer"
    
    psdjs_root_dir =  Rails.root.join 'lib', 'psd.js'
    extractor_script = File.join psdjs_root_dir, 'tasks', 'extract.coffee'
    coffee_script = 'coffee'
    
    extractor_command = "#{coffee_script} #{extractor_script} #{photoshop_file} #{processed_folder} #{design.safe_name_prefix}"

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
    
    # If there are clipping layers in design, then merge them using photoshop
    if File.exists? clipping_layer_check_file
      FileUtils.rm clipping_layer_check_file
      Log.info "Clipping layers found, queuing up for photoshop processing"
      Resque.enqueue PreProcessorJob, design.get_processing_queue_message
      return
    end
    
    fixed_width_cmd = "convert #{screenshot_file} -thumbnail '600x480>' -unsharp 0x.8 #{fixed_width_file}"
    thumbnail_cmd   = "convert #{screenshot_file} -thumbnail '180x240>' -unsharp 0x.8 #{thumbnail_file}"
    
    Log.info fixed_width_cmd
    system fixed_width_cmd
    
    Log.info thumbnail_cmd
    system thumbnail_cmd
    
    Store.save_to_store processed_file, File.join(design.store_extracted_key, "#{design.safe_name_prefix}.json")
    Store.save_to_store screenshot_file, File.join(design.store_extracted_key, "#{design.safe_name_prefix}.png")
    Store.save_to_store fixed_width_file, File.join(design.store_extracted_key, "#{design.safe_name_prefix}-fixed.png")
    Store.save_to_store thumbnail_file, File.join(design.store_extracted_key, "#{design.safe_name_prefix}-thumbnail.png")

    design.set_status Design::STATUS_EXTRACTED
    Log.info "Sucessfully completed extracting from photoshop file #{design.name}."
    
    Resque.enqueue ParserJob, design.id
  end
end
