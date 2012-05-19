module Constants
  
  # a photoshop with more than a million pixels in height/width? I don't think so! 
  Constants::INF = 1000000
  
  Constants::GRID_ORIENT_LEFT = 'left'
  Constants::GRID_ORIENT_NORMAL = 'normal'
  
  # Round to nearest 5
  def Constants::round_to_nearest_five(num)
    (((num + 5 )/5)-1)*5
  end

  def Constants::dummy_layer_hash
    dummy_layer_json = File.open(Rails.root.join('app','assets','javascripts','dummy_layer.json'),'r').read
    JSON.parse dummy_layer_json, :symbolize_names => true
  end
  
end