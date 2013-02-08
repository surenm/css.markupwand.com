class ChatNotifyJob
  extend Resque::Plugins::History

  @queue = :misc_tasks

  def self.perform(message)
    Utils::post_to_chat message
  end
end