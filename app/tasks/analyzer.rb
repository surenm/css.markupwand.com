require "pp"

class Analyzer
  def self.get_dom_map(layers)
    bounding_rectangles = layers.collect do |layer|
      PhotoshopItem::LayerBounds.new layer
    end
    
    bounding_rectangles.sort!
    
    layers_count = bounding_rectangles.size
    grid = Array.new(layers_count) { Array.new }
    for i in 0..(layers_count-1)
      for j in 0..(layers_count-1)
        first = bounding_rectangles[i]
        second = bounding_rectangles[j]
        if i != j and first.encloses? second
          grid[i].push(j)
        end
      end
    end
    
    for i in 0..(layers_count-1)
      puts "#{bounding_rectangles[i].name}"
      pp grid[i]
    end
  end
  
  
  def self.analyze(psd_json_data)
    layers = JSON.parse psd_json_data, :symbolize_names => true
    
    dom_map = self.get_dom_map layers
    return true
  end
end