class PollerJob
  @queue = :poller
  
  def self.perform(design_id, callback_uri)
    design = Design.find design_id
    done_file = File.join design.store_processed_key, "zzzzzzzzzz_done"
    
    bucket = Store::get_remote_store
    done_object = bucket.objects[done_file]
    while not done_object.exists?
      Log.debug "Still waiting for #{done_object.key}..."
      sleep 5
    end
    
    post_data = { :design => design.safe_name, :user => design.user, :store => Store::get_S3_bucket_name }

    begin
      # ping web server for immediate processing
      Log.info "Posting to #{callback_uri} signalling completion..."
      uri = URI(callback_uri)
      response = Net::HTTP.post_form uri, post_data
      Log.info response.body
    rescue Exception => e
      Log.fatal e
    end
  end
end