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
    return true if Rails.env.production? or ENV['UPLOAD_TO_AWS'] == "true"
    return false if Rails.env.development?
  end
  
  def Constants::store_local?
    !Constants::store_remote?
  end
end