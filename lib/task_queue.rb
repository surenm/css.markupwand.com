module TaskQueue
  if Constants::store_remote?
    TaskQueue::SQS = AWS::SQS.new
  end
  
  def TaskQueue::get_queue_name
    "markupwand_#{Rails.env}"
  end
  
  def TaskQueue::push_to_SQS(message)
    queue = TaskQueue::get_queue

    Log.info "Pushing design: '#{message}' to #{queue.url}..."
    queue.send_message message
  end
  
  def TaskQueue::parse_locally(message)
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
  
  def TaskQueue::push(message)
    if Constants::store_local?
      TaskQueue::parse_locally message
    else
      TaskQueue::push_to_SQS message
    end
  end
  
  def TaskQueue::get_queue
    queue_name = TaskQueue::get_queue_name
    begin
      queue = TaskQueue::SQS.queues.named queue_name
    rescue AWS::SQS::Errors::NonExistentQueue
      queue = TaskQueue::SQS.queues.create queue_name
    end
    return queue
  end
end