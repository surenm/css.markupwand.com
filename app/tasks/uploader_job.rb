class UploaderJob
  extend Resque::Plugins::History
  @queue = :uploader
  
  def self.perform(design_id, design_data)
    design_data.symbolize_keys!
    
    design = Design.find design_id
    design.set_status Design::STATUS_UPLOADING
    Log.info "Uploading design file for #{design.id}..."

    user = design.user

    Resque.enqueue ChatNotifyJob, design.id, "uploaded"
    
    safe_basename = Store::get_safe_name File.basename(design_data[:name], ".psd")
  
    file_name = "#{safe_basename}.psd" 
    file_url  = design_data[:file_url].to_s
    Log.info "Fetching #{file_name} at #{file_url} from Filepicker.io ... "
    
    response      = RestClient.get file_url
    psd_file_data = response.body    

    destination_file = File.join design.store_key_prefix, file_name
    Store.write_contents_to_store destination_file, psd_file_data
    
    original_file_backup = File.join design.store_key_prefix, "#{file_name}.orig"
    Store.write_contents_to_store original_file_backup, psd_file_data
    
    design.psd_file_path = destination_file
    design.save!
    Log.info "Done uploading successfully!"
    
    design.set_status Design::STATUS_UPLOADED
    design.push_to_processing_queue
  end
end