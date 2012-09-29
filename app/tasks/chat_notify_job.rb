class ChatNotifyJob
  extend Resque::Plugins::History

  @queue = :misc_tasks

  def self.perform(design_id, event)
    design = Design.find design_id
    user = design.user

    case event
    when "uploaded"
      Utils::post_to_chat "#{user.name.to_s} <#{user.email.to_s}> uploaded <a href='http://www.markupwand.com/design/#{design.safe_name.to_s}'>#{design.safe_name_prefix}</a>"
    when "completed"
      Utils::post_to_chat "#{user.name.to_s} <#{user.email.to_s}>'s design (<a href='http://www.markupwand.com/design/#{design.safe_name.to_s}'>#{design.safe_name_prefix}</a>) completed in #{design.get_conversion_time}"
    end
  end
end