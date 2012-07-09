module Utils
  def Utils::strip_unwanted_attrs_from_html(html)
    dom = Nokogiri::HTML::Document.parse html
    Utils.strip_unwanted_attrs_from_dom dom
    return dom.serialize
  end

  def Utils::strip_unwanted_attrs_from_dom(dom)
    data_attributes = ['data-grid-id', 'data-layer-id', 'data-layer-name', 'enable_data_attributes', 'tag']
    dom.children.each do |child_dom|
      data_attributes.each do |attribute|
        attributes = child_dom.remove_attribute attribute if child_dom.attributes.has_key? attribute
      end
      Utils.strip_unwanted_attrs_from_dom child_dom
    end
  end

  def Utils::pager_duty_alert(service_key, file_name, error, user)
    Log.debug "Sending message to pager duty"
    post_data = {
        "service_key" => service_key,
        "event_type" => "trigger",
        "description" => "<FAILURE>\nUser:#{user}\nFile: #{file_name}\nReason:#{error.to_s}",
        "details" => {
            "file" => file_name,
            "error" => error,
            "user" => user
        }
    }
    payload = post_data.to_json
    req = Net::HTTP::Post.new('/generic/2010-04-15/create_event.json', initheader = {'Content-Type' => 'application/json'})
    req.body = payload
    response = Net::HTTP.new("events.pagerduty.com", '80').start { |http| http.request(req) }
    Log.debug "Response #{response.code} #{response.message}:#{response.body}"
  end
end