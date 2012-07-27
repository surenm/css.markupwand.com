require 'net/http'
require 'json'

module ApplicationHelper
  def ApplicationHelper::get_json(url)
    url = URI.parse(url)
    req = Net::HTTP::Get.new(url.path)
    res = Net::HTTP.start(url.host, url.port) do |http|
      http.request(req)
    end
    
    JSON.parse res.body
  end

  def ApplicationHelper::post_simple_message(to, subject, text)
    return if Rails.env.development? or Constants::DISABLE_MAILS
    RestClient.post "https://api:key-3k01b6wme8-hzvhyowno9r0gccep7e17"\
      "@api.mailgun.net/v2/markupwand.mailgun.org/messages",
      :from => "Markupwand <hackers@markupwand.com>",
      :to => to,
      :subject => subject,
      :text => text
  end

  def ApplicationHelper::post_to_grove(message)
    grove = Grove.new(ENV['GROVE_CHANNEL_KEY'], :service => 'Markupwand', :icon_url => 'http://www.markupwand.com/favicon.ico')
    grove.post message
  end

end
