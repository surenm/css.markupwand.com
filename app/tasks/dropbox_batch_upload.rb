class DropboxBatchUpload
  def self.upload_from_dropbox()
    client = Dropbox::API::Client.new :token => Dropbox::OAUTH_TOKEN, :secret => Dropbox::OAUTH_TOKEN_SECRET
    files = client.search 'psd'

    # Just use designs from the test cases folder 
    files.each do |file|
      if file["path"].include? "/markupwand/psd_sources/Test cases" and File.extname(file['path']) == ".psd"
        file_name = File.basename file["path"]
        file_body = file.download

        tmp_file_name = Rails.root.join 'tmp', file_name
        fptr = File.open(tmp_file_name, 'wb')
        fptr.write(file_body)
        fptr.close

        self.create_design_from_file tmp_file_name
      end
    end
    return
  end

  def self.upload_from_localhost(folder_name)
    Dir["#{folder_name}/**/*.psd"].each do |file|
      self.create_design_from_file file
    end
  end

  def self.create_design_from_file(file_name)
    design      = Design.new :name => File.basename(file_name)
    design.user = User.find_by_email "suren@markupwand.com"
    design.save!

    safe_basename = Store::get_safe_name File.basename(file_name, ".psd")
    safe_filename = "#{safe_basename}.psd"
    destination_file = File.join design.store_key_prefix, safe_filename
    Store.save_to_store file_name, destination_file
    
    design.psd_file_path = destination_file
    design.save!
    
    design.push_to_processing_queue
  end
end