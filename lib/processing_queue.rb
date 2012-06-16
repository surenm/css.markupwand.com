module ProcessingQueue
  if Constants::store_remote?
    ProcessingQueue::SQS = AWS::SQS.new
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

  def ProcessingQueue::push_to_SQS(message)
    queue = ProcessingQueue::get_queue

    Log.info "Pushing design: '#{message}' to #{queue.url}..."
    queue.send_message message
  end
  
  def ProcessingQueue::parse_locally(message)
    Log.info "Polling local photoshop with '#{message}'..."
    Resque.enqueue LocalProcessorJob, message  
  end
  
  def ProcessingQueue::push(message)
    if Constants::store_local?
      ProcessingQueue::parse_locally message
    else
      ProcessingQueue::push_to_SQS message
    end
  end
end