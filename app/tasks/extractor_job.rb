require 'open3'
class ExtractorJob
  extend Resque::Plugins::History
  @queue = :worker
  
  def self.perform(design_id)
    design = Design.find design_id
    user = design.user
    design.set_status Design::STATUS_EXTRACTING

    Log.info "Extracting design data from photoshop file #{design.name}..."
    
    design_folder  = Store.fetch_from_store design.store_key_prefix
    photoshop_file = Rails.root.join 'tmp', 'store', design.psd_file_path
    psd_file_root  = File.basename design.psd_file_path, '.psd'
    
    extracted_folder = Rails.root.join 'tmp', 'store', design.store_extracted_key
    FileUtils.mkdir_p extracted_folder if not Dir.exists? extracted_folder

    extracted_file   = Rails.root.join extracted_folder, "#{design.safe_name_prefix}.json"
    screenshot_file  = Rails.root.join extracted_folder, "#{design.safe_name_prefix}.png"
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
  
    # Build, thumbnail files
    thumbnail_cmd   = "convert #{screenshot_file} -thumbnail '180x240>' -unsharp 0x.8 #{thumbnail_file}"
    
    Log.info thumbnail_cmd
    system thumbnail_cmd
    
    Store.save_to_store extracted_file, File.join(design.store_extracted_key, "#{design.safe_name_prefix}.json")
    Store.save_to_store screenshot_file, File.join(design.store_extracted_key, "#{design.safe_name_prefix}.png")
    Store.save_to_store thumbnail_file, File.join(design.store_extracted_key, "#{design.safe_name_prefix}-thumbnail.png")

    design.set_status Design::STATUS_EXTRACTING_DONE
    Log.info "Sucessfully completed extracting from photoshop file #{design.name}."

    # Build sif file from extracted file    
    Log.info "Building SIF File from extracted file..."
    SifBuilder.build_from_extracted_file design, extracted_file
    Log.info "Successfully built SIF file."

    if design.photoshop_status != Design::STATUS_PROCESSING_DONE
      Log.info "Images processing isn't complete. Queuing up for images extraction..."
      design.push_to_images_queue
    else
      ImagesCompletedJob.perform design.id 
    end
    
    CssMarkupwandJob.perform design.id
    Resque.enqueue ChatNotifyJob, "#{user.name.to_s} (#{user.email.to_s})'s design (<a href='http://css.markupwand.com/design/#{design.safe_name.to_s}'>#{design.safe_name_prefix}</a>)"
  end
end
