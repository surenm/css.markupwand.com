class MiscTasks::InvalidDesignJob
  extend Resque::Plugins::History
  
  @queue = :misc_tasks
  def self.perform(design_id)
    design = Design.find design_id
    
    if design.psd_file_path.nil?
      Log.fatal "Design file missing"
      design.add_tag Design::ERROR_FILE_ABSENT
      design.tags.uniq!
      design.save!
      return
    end
      
    photoshop_file = Store::fetch_object_from_store(design.psd_file_path)
    mime_type_string = `file --mime "#{photoshop_file}"`
    matches = mime_type_string.scan(/image\/vnd.adobe\.photoshop/)
    if matches.size == 0
      Log.fatal "Design is not a valid photoshop file"
      design.add_tag Design::ERROR_NOT_PHOTOSHOP_FILE
      design.tags.uniq!
      design.save!
      return
    end
  end
end