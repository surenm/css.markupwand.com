module Store
  # Static instance to reference to access AWS S3 instance
  if Constants::store_remote?
    Store::S3 = AWS::S3.new
  end
  
  Store::LOCAL_STORE = ENV["LOCAL_STORE"]
  
  def Store::get_safe_name(name)
    name.gsub(/[^0-9a-zA-Z]/,'_')
  end
  
  def Store::get_S3_bucket_name
    "store_#{Rails.env}"
  end
  
  def Store::get_remote_store
    bucket_name = Store::get_S3_bucket_name
    bucket = Store::S3.buckets[bucket_name]
    if not bucket.exists?
      bucket = Store::S3.buckets.create bucket_name
    end
    return bucket
  end
  
  def Store::get_local_store
    root_dir = Store::LOCAL_STORE
    if not Dir.exists? root_dir
      Dir.mkdir root_dir
    end
    
    root_dir
  end
  
  def Store::write_contents_to_local_file(file_path, file_contents)
    file_dir = File.dirname file_path
  
    FileUtils.mkdir_p file_dir  if not Dir.exists? file_dir
    
    fptr = File.open file_path, 'wb'
    fptr.write file_contents
    fptr.close
  end
  
  def Store::write_contents_to_remote_store(file_key, file_contents)
    s3_bucket = Store::get_remote_store

    Log.debug "Saving contents to #{file_key} in remote store #{s3_bucket.name}..."

    fptr = s3_bucket.objects[file_key]
    fptr.write file_contents
  end
  
  def Store::write_contents_to_local_store(file_key, file_contents)
    local_store = Store::get_local_store
    
    Log.debug "Saving contents to #{file_key} in local store..."
    
    file_path   = File.join local_store, file_key
    Store::write_contents_to_local_file file_path, file_contents
  end
  
  def Store::write_contents_to_store(file_key, file_contents)
    if Constants::store_remote?
      Store::write_contents_to_remote_store file_key, file_contents
    else 
      Store::write_contents_to_local_store file_key, file_contents
    end
  end
  
  # Write to a target url
  # Usually, target = /email/safe_filename/, url = http://filepicker.io/api/xxx
  def Store::write_from_url(target, url)
    response      = RestClient.get url
    response_data = response.body
    Store::write_contents_to_store(target, response_data)
  end

  def Store::copy_within_local_store(src_path, destination_path)
    local_store = Store::get_local_store
    
    abs_src_file = File.join local_store, src_path

    abs_destination_file = File.join local_store, destination_path
    abs_destination_dir  = File.dirname abs_destination_file
    if not Dir.exists? abs_destination_dir
      FileUtils.mkdir_p abs_destination_dir
    end

    if File.directory?(abs_src_file)
      abs_src_file += '/.'
    end
    
    Log.info "Copying locally from #{abs_src_file} to #{abs_destination_file}"
    FileUtils.cp_r abs_src_file, abs_destination_file
  end
  
  def Store::copy_within_remote_store(src_path, destination_path)
    s3_bucket = Store::get_remote_store
    
    Log.debug "Copying #{src_path} from #{s3_bucket.name} to #{destination_path}..."
    
    source_object      = s3_bucket.objects[src_path]
    destination_object = s3_bucket.objects[destination_path]

    if source_object.exists?
      source_object.copy_to destination_object
    end    
  end
  
  def Store::copy_within_store_recursively(src_folder, destination_folder)
    if Constants::store_remote?
      s3_bucket = Store::get_remote_store
      objects = s3_bucket.objects.with_prefix src_folder
      objects.each do |file|
        src_pathname = Pathname.new file.key
        file_relative_key = src_pathname.relative_path_from(Pathname.new src_folder)

        destination_path = File.join destination_folder, file_relative_key
        Store::copy_within_remote_store file.key, destination_path
      end
    else 
      Store::copy_within_local_store src_folder, destination_folder
    end
  end
  
  def Store::copy_within_store(src_file_path, destination_file_path)
    if Constants::store_remote?
      Store::copy_within_remote_store src_file_path, destination_file_path
    else 
      Store::copy_within_local_store src_file_path, destination_file_path
    end
  end
    
  def Store::save_to_store(src_file_path, destination_file_path)
    src_file_contents = File.read src_file_path
    if Constants::store_remote?
      Store::write_contents_to_remote_store destination_file_path, src_file_contents
    else 
      Store::write_contents_to_local_store destination_file_path, src_file_contents
    end
  end
  
  def Store::fetch_from_remote_store(remote_folder)
    bucket = Store::get_remote_store
    
    tmp_folder  = Rails.root.join 'tmp', 'store'
    actual_folder = Rails.root.join 'tmp', 'store', remote_folder
    Log.debug "Fetching #{remote_folder} from Remote store #{bucket.name} to #{tmp_folder}..."

    files = bucket.objects.with_prefix remote_folder
    files.each do |file|
      contents = file.read

      destination_path = File.join tmp_folder, file.key
      
      Log.debug "Fetching #{file.key} from Remote store to #{destination_path}"
      Store::write_contents_to_local_file destination_path, contents
    end
    return actual_folder
  end
  
  def Store::fetch_from_local_store(remote_folder)
    local_store  = Store::get_local_store
    abs_remote_folder = File.join local_store, remote_folder
    
    tmp_folder = Rails.root.join 'tmp', 'store', remote_folder
    Log.debug "Fetching #{remote_folder} from local store #{local_store} to #{tmp_folder}..."

    files = Dir["#{abs_remote_folder}/**/*"]
    Log.debug files
    files.each do |file|
      next if File.directory? file

      contents = File.read file

      file_pathname  = Pathname.new file
      store_file_key = file_pathname.relative_path_from(Pathname.new abs_remote_folder)      
      destination_path = File.join tmp_folder, store_file_key
      
      Log.debug "Fetching #{store_file_key} from local store to #{destination_path}"
      Store::write_contents_to_local_file destination_path, contents
    end
    return tmp_folder  
  end
  
  def Store::fetch_from_store(remote_folder)
    if Constants::store_remote?
      return Store::fetch_from_remote_store remote_folder
    else 
      return Store::fetch_from_local_store remote_folder
    end    
  end
  
  def Store::fetch_object_from_remote_store(remote_file_path)
    bucket      = Store::get_remote_store
    remote_file = bucket.objects[remote_file_path]

    tmp_file = Rails.root.join 'tmp', 'store', remote_file_path
    contents = remote_file.read
    Log.debug "Fetching #{remote_file_path} from remote store #{bucket.name} to #{tmp_file}..."    
    Store::write_contents_to_local_file tmp_file, contents
    
    return tmp_file
  end
  
  def Store::fetch_object_from_local_store(remote_file_path)
    local_store = Store::get_local_store
    remote_file = File.join local_store, remote_file_path
    
    tmp_file = Rails.root.join 'tmp', 'store', remote_file_path
    contents = File.read remote_file
    
    Log.debug "Fetching #{remote_file} from local store #{local_store} to #{tmp_file}..."    
    Store::write_contents_to_local_file tmp_file, contents
    
    return tmp_file
  end
  
  def Store::fetch_object_from_store(remote_file)
    if Constants::store_remote?
      return Store::fetch_object_from_remote_store remote_file
    else 
      return Store::fetch_object_from_local_store remote_file
    end    
  end
  
  def Store::delete_from_remote_store(file_path)
    Log.debug "Deleting #{file_path} from remote store..."
    bucket = Store::get_remote_store
    files = bucket.objects.with_prefix file_path
    files.each { |file_obj| file_obj.delete }  
  end
  
  def Store::delete_from_local_store(file_path)
    Log.debug "Deleting #{file_path} from local store..."
    local_store = Store::get_local_store
    abs_file_path = File.join local_store, file_path
    FileUtils.rm_r abs_file_path if File.exists? abs_file_path
  end
  
  def Store::delete_from_store(remote_file_path)
    if Constants::store_remote?
      Store::delete_from_remote_store remote_file_path
    else 
      Store::delete_from_local_store remote_file_path
    end
  end
end
