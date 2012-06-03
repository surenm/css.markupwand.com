module Store
  # Static instance to reference to access AWS S3 instance
  Store::S3 = AWS::S3.new
  
  # Prefix for all buckets in AWS
  Store::BUCKET_ROOT = "store"

  def Store::get_s3_bucket_name
    "#{Store::BUCKET_ROOT}_#{Rails.env}"
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
    root_dir = File.join Rails.root.to_s, 'store'
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
    if Rails.env == "production" or ENV['UPLOAD_TO_AWS'] == "true"
      Store::write_to_S3 file_key, file_contents
    else 
      Store::write_to_local file_key, file_contents
    end
  end
end