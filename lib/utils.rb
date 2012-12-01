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

  def Utils::pager_duty_alert(error_description, args)
    return if Rails.env.development?
    
    Log.debug "Sending message to pager duty..."  
    service_key = "f36e4c80ab63012f5d3622000af84f12"
    post_data = {
        "service_key" => service_key,
        "event_type"  => "trigger",
        "description" => error_description,
        "details"     => args
    }
    payload = post_data.to_json
    req = Net::HTTP::Post.new('/generic/2010-04-15/create_event.json', initheader = {'Content-Type' => 'application/json'})
    req.body = payload
    response = Net::HTTP.new("events.pagerduty.com", '80').start { |http| http.request(req) }
    Log.debug "Response #{response.code} #{response.message}:#{response.body}"
    Utils::post_to_chat("[Pagerduty] " + error_description, 'red')
  end

  def Utils::post_to_chat(message, color = 'gray', notify = true)
    client = HipChat::Client.new(ENV['HIPCHAT_TOKEN'])
    client['Markupwand'].send('markupwand', message, :notify => notify, :color => color)
  end
  
  def Utils::debug_intersecting_layers(layers)
    url = "http://markupwand-utils.herokuapp.com/index.html?points="
    layers.each do |layer|
      bounds_string = "(#{layer.bounds.top},#{layer.bounds.left},#{layer.bounds.bottom},#{layer.bounds.right})-"
      url += bounds_string
    end
    return url
  end

  def Utils::process_all_designs(folder_name)
    user = User.find_by_email "bot@goyaka.com"

    Dir["#{folder_name}/**/*.psd"].each do |psd_file|
      file_name   = File.basename psd_file

      design      = Design.new :name => file_name
      design.user = user    
      design.save!

      safe_basename = Store::get_safe_name File.basename(file_name, ".psd")
      safe_filename = "#{safe_basename}.psd"
      destination_file = File.join design.store_key_prefix, safe_filename
      Store.save_to_store psd_file, destination_file

      design.psd_file_path = destination_file
      design.save!

      design.push_to_extraction_queue
    end
  end

  def Utils::prune_null_items(object)
    new_object = Hash.new
    object.each do |key, value|
      new_object[key] = value if not value.nil?
    end
  end

  def Utils::non_zero_spacing(spacing)
    if spacing[:top] == 0 and spacing[:bottom] == 0 and spacing[:left] == 0 and spacing[:right] == 0
      return false
    else
      return true
    end
  end
  
  def Utils::build_stylesheet_block(class_name, styles_array, children_tree_css="")
    styles_string = styles_array.join(";\n") + ";"
    css_block = <<-CSS
.#{class_name} {
#{styles_string}
#{children_tree_css}
}
CSS
    return css_block
  end
  
  def Utils::indent_scss(unindented_scss)
    scss_code = ""
    tabs = 0
    unindented_scss.split("\n").each do |line|
      tabs = tabs - 1  if line.include? '}'
      white_space = Array.new(tabs, '    ').join
      scss_code += "#{white_space}#{line}\n"
      tabs = tabs + 1 if line.include? '{'
    end
    return scss_code
  end
end
