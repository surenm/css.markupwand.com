class DesignUploader < CarrierWave::Uploader::Base
  storage :file

  def store_dir
    "uploads/#{model.id.to_s}"
  end
end