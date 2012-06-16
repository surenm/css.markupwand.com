class UploaderJob
  @queue = :uploader
  
  def self.perform(design_id, design_data, callback_url)
    Log.level = Log4r::debug
    
    design_data.symbolize_keys!
    
    design = Design.find design_id
    Log.info "Uploading design file for #{design.id}..."
    
    file_name = Store::get_safe_name design_data[:name]
    file_url  = design_data[:file_url].to_s
    Log.info "Fetching #{file_name} at #{file_url} from Filepicker.io ... "
    
    response      = RestClient.get file_url
    psd_file_data = response.body    

    destination_file = File.join design.store_key_prefix, file_name
    Store.write_contents_to_store destination_file, psd_file_data
    
    design.psd_file_path = destination_file
    design.save!
    Log.info "Done uploading successfully!"
    
    design.push_to_processing_queue callback_url
  end
end