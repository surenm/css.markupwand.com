class ChatNotifyJob
  extend Resque::Plugins::History

  @queue = :misc_tasks

  def self.perform(design_id, event)
    return if Rails.env.development?
    design = Design.find design_id
    user = design.user

    case event
    when "uploaded"
      Utils::post_to_chat "#{user.name.to_s} (#{user.email.to_s}) uploaded <a href='http://css.markupwand.com/design/#{design.safe_name.to_s}'>#{design.safe_name_prefix}</a>"
    when "completed"
      Utils::post_to_chat "#{user.name.to_s} (#{user.email.to_s})'s design (<a href='http://css.markupwand.com/design/#{design.safe_name.to_s}'>#{design.safe_name_prefix}</a>) completed in #{design.get_conversion_time}"
    when "images-completed"
      Utils::post_to_chat "#{user.name.to_s} (#{user.email.to_s})'s images are completed"
    when "paid-user"
      Utils::post_to_chat "#{user.name.to_s} (#{user.email.to_s}) signed up for #{user.plan} plan"
    end
    end
  end
end