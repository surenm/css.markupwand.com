module TaskQueue
  if Constants::store_remote?
    TaskQueue::SQS = AWS::SQS.new
  end
  
  def TaskQueue::get_queue_name
    "markupwand_#{Rails.env}"
  end
  
  def TaskQueue::push_to_SQS(message)
    queue = TaskQueue::get_queue
    queue.send_message message
    Log.fatal "Pushed design #{message} to #{queue}"
  end
  
  def TaskQueue::poll_local(message)
    #TODO: Extend script might be up and running. Poll it saying new design has arrived
    Log.fatal "Polling local instance with message"
  end
  
  def TaskQueue::push(message)
    if Constants::store_local?
      TaskQueue::poll_local message
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