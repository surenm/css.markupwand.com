class PollerJob
  @queue = :poller
  
  def self.perform(design_id)
    design = Design.find design_id
    done_file = File.join design.store_processed_key, "zzzzzzzzzz_done"
    
    bucket = Store::get_remote_store
    done_object = bucket.objects[done_file]
    while not done_object.exists?
      Log.debug "Still waiting for #{done_object.key}..."
      sleep 10
    end
    
    Resque.enqueue ParserJob, design.safe_name
  end
end