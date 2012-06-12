module ProcessingQueue
  if Constants::store_remote?
    ProcessingQueue::SQS = AWS::SQS.new
  end

  def ProcessingQueue::push_to_SQS(message)
    queue = ProcessingQueue::get_queue

    Log.info "Pushing design: '#{message}' to #{queue.url}..."
    queue.send_message message
  end
  
  def ProcessingQueue::parse_locally(message)
    Log.info "Polling local photoshop with '#{message}'..."
    scripts_dir = File.join Constants::local_scripts_folder
    if not Dir.exists? scripts_dir
      Log.fatal "Scripts directory does not exists... Make sure to 'rake deploy' transformers"
      return
    end
    
    local_command = "cd '#{scripts_dir}' && rake handle_local_message['#{message}']"
    Log.info local_command
    system(local_command)    
    
  end
  
  def ProcessingQueue::push(message)
    if Constants::store_local?
      ProcessingQueue::parse_locally message
    else
      ProcessingQueue::push_to_SQS message
    end
  end
  
  def ProcessingQueue::get_queue
    queue_name = Constants::PROCESSING_QUEUE
    begin
      queue = ProcessingQueue::SQS.queues.named queue_name
    rescue AWS::SQS::Errors::NonExistentQueue
      queue = ProcessingQueue::SQS.queues.create queue_name
    end
    return queue
  end
end