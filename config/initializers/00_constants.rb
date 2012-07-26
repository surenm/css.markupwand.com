module Constants
  
  # a photoshop with more than a million pixels in height/width? I don't think so! 
  Constants::INF = 1000000
  
  Constants::GRID_ORIENT_LEFT = :left
  Constants::GRID_ORIENT_NORMAL = :normal
  
  # Queues:
  Constants::PROCESSING_QUEUE = "markupwand-processing"
  
  # Max retry with grouping
  Constants::GROUPING_MAX_RETRIES = 3
  
  # Disable mails if env variable is set
  Constants::DISABLE_MAILS = false
  if ENV['DISABLE_MAILS'] == "true"
    Constants::DISABLE_MAILS = true
  end
  
  # Round to nearest 5
  def Constants::round_to_nearest_five(num)
    (((num + 5 )/5)-1)*5
  end  

  # Just the store location in the initializer. All other Store definition in Store library
  def Constants::store_remote?
    return true if Rails.env.production? or Rails.env.staging? or ENV['REMOTE'] == "true"
    return false if Rails.env.development?
  end
  
  def Constants::store_local?
    !Constants::store_remote?
  end
  
  def Constants::local_scripts_folder
    # shouldn't even come here if this is production
    if Constants::store_local?
      return File.join ENV['HOME'], "Library", "Application Support", "Transformers"
    end
  end

  def Constants::css_properties
    if not TransformersWeb::Application.config.respond_to? 'css_properties'
      properties_str = File.open(Rails.root.join('db', 'json', 'css', 'css_properties.json')).read
      TransformersWeb::Application.config.css_properties = JSON.parse properties_str, :symbolize_names => true
    end

    TransformersWeb::Application.config.css_properties
  end

end