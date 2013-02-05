module Constants
  
  # a photoshop with more than a million pixels in height/width? I don't think so! 
  Constants::INF = 1000000
  
  Constants::GRID_ORIENT_LEFT = 'left'
  Constants::GRID_ORIENT_NORMAL = 'normal'
  
  # Queues:
  Constants::PROCESSING_QUEUE = "markupwand-processing"
  
  # Max retry with grouping
  Constants::GROUPING_MAX_RETRIES = 3
  
  # Disable mails if env variable is set

  Constants::PAGERDUTY_TRANSFORMERS_WEB = "f36e4c80ab63012f5d3622000af84f12"
  Constants::PAGERDUTY_WINDOWS_MACHINE_STUCK = "3fdd82b018390130a4ce22000afc4cb2"
  
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

  Constants::COMPASS_CONFIG = Rails.application.config.compass.sass_load_paths

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
end