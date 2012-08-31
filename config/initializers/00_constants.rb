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
  
  if ENV['DISABLE_MAILS'] == "true"
    Constants::DISABLE_MAILS = true
  else
    Constants::DISABLE_MAILS = false
  end
  
  # Set local environment variables from constants.yml. In production, if needed, set this once at heroku
  if Rails.env.development? 
    yaml_data = YAML.load_file Rails.root.join("config", "local_constants.yml")
    yaml_data.each do |key, value|
      ENV[key] = value
    end
  end

  # Load everything in env file to environment
  env_file = Rails.root.join '.env'
  contents = File.read env_file
  contents.each_line do |line|
    words = line.split "="
    key = words[0]
    value = words[1]
    ENV[key] = value
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

  def Constants::invite_gated?
    if ENV['GATE_CLOSED'] == "true"
      return true
    else
      return false
    end
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