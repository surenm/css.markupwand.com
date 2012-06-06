if Constants::store_remote?
  class DesignUploader < CarrierWave::Uploader::Base
    include CarrierWaveDirect::Uploader
    
    include ActiveModel::Conversion
    extend ActiveModel::Naming
  end
else
  class DesignUploader < CarrierWave::Uploader::Base
    storage :file
    
    def store_dir
      "uploads/#{model.id.to_s}"
    end
  end
end

