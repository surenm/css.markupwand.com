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
end
