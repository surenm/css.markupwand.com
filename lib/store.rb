module Store
  # Static instance to reference to access AWS S3 instance
  if Constants::store_remote?
    Store::S3 = AWS::S3.new
  end
  
  Store::LOCAL_STORE = File.join Dir.home, "store_local"
  
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

    Log.info "Saving contents to #{file_key} in remote store #{s3_bucket.name}..."

    fptr = s3_bucket.objects[file_key]
    fptr.write file_contents
  end
  
  def Store::write_contents_to_local_store(file_key, file_contents)
    local_store = Store::get_local_store
    
    Log.info "Saving contents to #{file_key} in local store..."
    
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
  
  def Store::copy_within_local_store(src_path, destination_path)
    local_store = Store::get_local_store
    
    abs_src_file = File.join local_store, src_path

    abs_destination_file = File.join local_store, destination_path
    abs_destination_dir  = File.dirname abs_destination_file
    if not Dir.exists? abs_destination_dir
      FileUtils.mkdir_p abs_destination_dir
    end
    
    FileUtils.cp abs_src_file, abs_destination_file
  end
  
  def Store::copy_within_remote_store(src_path, destination_path)
    s3_bucket = Store::get_remote_store

    source_object      = s3_bucket.objects[src_path]
    destination_object = s3_bucket.objects[destination_path]

    if source_object.exists?
      source_object.copy_to destination_object
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
    local_folder  = Rails.root.join 'tmp', 'store'
    
    Log.info "Fetching #{remote_folder} from Remote store #{bucket.name} to #{local_folder}..."

    files = bucket.objects.with_prefix remote_folder
    files.each do |file|
      contents = file.read
      absolute_destination_file = File.join local_folder, file.key
      
      Log.info "Fetching #{file.key} from Remote store to #{absolute_destination_file}"
      Store::write_contents_to_local_file absolute_destination_file, contents
    end
  end
  
  def Store::fetch_from_local_store(remote_folder)
    local_store  = Store::get_local_store

    tmp_folder = Rails.root.join 'tmp', 'store', remote_folder
    
    Log.info "Fetching #{remote_folder} from local store #{local_store} to #{tmp_folder}..."

    absolute_remote_folder_path = File.join local_store, remote_folder
    files = Dir["#{absolute_remote_folder_path}/**/*"]
    Log.debug files
    files.each do |file|
      next if File.directory? file

      contents = File.read file
      
      file_pathname  = Pathname.new file
      store_file_key = file_pathname.relative_path_from(Pathname.new absolute_remote_folder_path)
      
      absolute_destination_file = File.join tmp_folder.to_s, store_file_key
      Log.info "Fetching #{store_file_key} from local store to #{absolute_destination_file}"
      Store::write_contents_to_local_file absolute_destination_file, contents
    end   
  end
  
  def Store::fetch_from_store(remote_folder)
    if Constants::store_remote?
      Store::fetch_from_remote_store remote_folder
    else 
      Store::fetch_from_local_store remote_folder
    end    
  end
  
  def Store::fetch_object_from_remote_store(remote_file)
    bucket      = Store::get_remote_store
    remote_file = bucket.objects[remote_file]

    tmp_file = Rails.root.join 'tmp', 'store', remote_file
    contents = remote_file.read
    Log.info "Fetching #{remote_file} from remote store #{bucket.nam} to #{tmp_file}..."    
    Store::write_contents_to_local_file tmp_file, contents
    
    return tmp_file
  end
  
  def Store::fetch_object_from_local_store(remote_file)
    local_store = Store::get_local_store
    remote_file = File.join local_store, remote_file
    
    tmp_file = Rails.root.join 'tmp', 'store', remote_file
    contents = File.read remote_file
    
    Log.info "Fetching #{remote_file} from local store #{local_store} to #{tmp_file}..."    
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
end
