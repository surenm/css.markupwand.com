module Constants
  
  # a photoshop with more than a million pixels in height/width? I don't think so! 
  Constants::INF = 1000000
  
  # Round to nearest 5
  def Constants::round_to_nearest_five(num)
    (((num + 5 )/5)-1)*5
  end
  
  
end