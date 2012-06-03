module Store
  # Static instance to reference to access AWS S3 instance
  Store::S3 = AWS::S3.new
  
  # Prefix for all buckets in AWS
  Store::BUCKET_ROOT = "store"

  def Store::get_s3_bucket_name
    "#{Store::BUCKET_ROOT}_#{Rails.env}"
  end
  
  def Store::get_s3_bucket
    bucket_name = Store::get_s3_bucket_name
    bucket = Store::S3.buckets[bucket_name]
    if not bucket.exists?
      bucket = Store::S3.buckets.create bucket_name
    end
    return bucket
  end
  
  def Store::write(design, file_name, file_contents)
    key = "#{design.user.email}/#{design.safe_name_prefix}-#{design.id}/#{file_name}"
    bucket = Store::get_s3_bucket
    file = bucket.objects[key]
    file.write file_contents
    return key
  end
end