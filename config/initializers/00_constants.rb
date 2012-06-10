module Constants
  
  # a photoshop with more than a million pixels in height/width? I don't think so! 
  Constants::INF = 1000000
  
  Constants::GRID_ORIENT_LEFT = 'left'
  Constants::GRID_ORIENT_NORMAL = 'normal'
  
  # Round to nearest 5
  def Constants::round_to_nearest_five(num)
    (((num + 5 )/5)-1)*5
  end  

  # Just the store location in the initializer. All other Store definition in Store library
  def Constants::store_remote?
    return true if Rails.env.production? or ENV['REMOTE'] == "true"
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
end