module Store
  # Static instance to reference to access AWS S3 instance
  if Constants::store_remote?
    Store::S3 = AWS::S3.new
  end
  
  Store::LOCAL_STORE = File.join Dir.home, "store"
  
  def Store::get_s3_bucket_name
    "store_#{Rails.env}"
  end
  
  def Store::get_S3_store
    bucket_name = Store::get_s3_bucket_name
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
  
  def Store::write_to_S3(file_key, file_contents)
    s3_bucket = Store::get_S3_store
    fptr = s3_bucket.objects[file_key]
    fptr.write file_contents
  end
  
  def Store::write_to_local(file_key, file_contents)
    local_store = Store::get_local_store
    file_path   = File.join local_store, file_key
    file_dir    = File.dirname file_path
    if not Dir.exists? file_dir
      FileUtils.mkdir_p file_dir
    end
    
    fptr = File.open file_path, 'wb'
    fptr.write file_contents
    fptr.close
  end
  
  def Store::write(file_key, file_contents)
    if Constants::store_remote?
      Store::write_to_S3 file_key, file_contents
    else 
      Store::write_to_local file_key, file_contents
    end
  end
  
  def Store::copy_within_local(src_file, destination_file)
    local_store     = Store::get_local_store

    abs_destination_file = File.join local_store, destination_file
    abs_destination_dir  = File.dirname abs_destination_file
    if not Dir.exists? abs_destination_dir
      FileUtils.mkdir_p abs_destination_dir
    end
    
    FileUtils.cp src_file, abs_destination_file
  end
  
  def Store::copy_within_S3(src_file, destination_file)
    s3_bucket     = Store::get_S3_store
    src_object    = s3_bucket.objects[src_file]
    file_basename = File.basename src_file

    destination_object = s3_bucket.objects[destination_file]

    if src_object.exists?
      src_object.copy_to destination_object
    end    
  end
  
  def Store::copy_from_local_to_S3(src_file, destination_file)
    src_fptr = File.open src_file
    local_file_contents = src_fptr.read
    src_fptr.close()
    Store::write_to_S3 destination_file, local_file_contents
  end
  
  def Store::copy(src_file_path, destination_file_path)
    if Constants::store_remote?
      Store::copy_within_S3 src_file_path, destination_file_path
    else 
      Store::copy_within_local src_file_path, destination_file_path
    end
  end
  
  def Store::copy_from_local(src_file_path, destination_file_path)
    if Constants::store_remote?
      Store::copy_from_local_to_S3 src_file_path, destination_file_path
    else 
      Store::copy_within_local src_file_path, destination_file_path
    end
  end
end