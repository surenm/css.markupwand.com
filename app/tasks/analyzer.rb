require "pp"

class Analyzer
  def self.get_dom_map(layers)
    bounding_rectangles = layers.collect do |layer|
      PhotoshopItem::Layer.new layer
    end
    
    bounding_rectangles.sort!
    
    # Find a grid map of enclosing rectangles
    # grid[i][j] is true if i-th rectangle encloses j-th rectangle
    layers_count = bounding_rectangles.size
    grid = Array.new(layers_count) { Array.new }
    for i in 0..(layers_count-1)
      for j in 0..(layers_count-1)
        first = bounding_rectangles[i]
        second = bounding_rectangles[j]
        if i != j and first.encloses? second
          grid[i].push j
        end
      end
    end
    
    # Build a tree adjancecy list out of the grid map
    # grid[i][j] is true if j-th rectangle is a direct child of i-th rectangle
    for i in 0..(layers_count-1)
      items_to_delete = []
      grid[i].each do |child|
        grid[child].each do |grand_child|
          items_to_delete.push grand_child
        end
      end
      
      items_to_delete.each do |item|
        grid[i].delete item
      end
    end
  
    for i in 0..(layers_count-1)
      puts "#{i}: #{bounding_rectangles[i].name}: #{grid[i]}"
    end
  end
  
  def self.get_content(layers)
    layers.collect do |layer_obj|
      layer = PhotoshopItem::Layer.new layer_obj
      layer.get_html_content
  def self.get_root_layer(dom_map)
    root = nil
    dom_map.each do |layer|
      flag = true
      dom_map.each do|inner_layer|
        if not layer.encloses? inner_layer
          flag = false
          break
        end
      end
      if flag
        root = layer
        break
      end
    end
    
    return root
  end
  end
  
  def self.analyze(psd_json_data)
    layers = JSON.parse psd_json_data, :symbolize_names => true
    dom_map = self.get_dom_map layers
    content_map = self.get_content layers
    return true
  end
end