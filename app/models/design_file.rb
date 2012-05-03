class DesignFile
  include Mongoid::Document
  include Mongoid::Versioning
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated
  
  UNASSIGNED=0
  ASSIGNED=1
  COMPLETED=2
  FAILED=-1
  TIMEDOUT=-2
  STATUS_TIMEOUT=300
  
  field :status, type: Integer, default: UNASSIGNED
  
  mount_uploader :file, DesignFileUploader
  
  def get_file
    file.store_dir + "/" + File.basename(file.to_s)
  end
end
