class LocalProcessorJob
  @queue = :local_processor
  def self.perform(message)
    scripts_dir = File.join Constants::local_scripts_folder
    if not Dir.exists? scripts_dir
      Log.fatal "Scripts directory does not exists... Make sure to 'rake deploy' transformers"
      return
    end
    
    local_command = "cd '#{scripts_dir}' && rake --trace handle_local_message['#{message}']"
    Log.info local_command
    system(local_command)    
  end
end