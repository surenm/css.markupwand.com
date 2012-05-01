class DesignFile
  include Mongoid::Document
  include Mongoid::Versioning
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated
  
  mount_uploader :file, DesignFileUploader
end
