class DesignUploader < CarrierWave::Uploader::Base
  storage :fog
  
  def store_dir
    "uploads/#{model.id.to_s}"
  end
  
end
