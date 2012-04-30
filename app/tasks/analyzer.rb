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
      bounding_rectangles[i].children = grid[i]
    end
    
    return bounding_rectangles
  end
  
  def self.get_root_layer(dom_map)
    root = nil
    dom_map.each do |layer|
      flag = true
      
      dom_map.each do |inner_layer|
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
  
  def self.generate_html(dom_map)
    root_node = self.get_root_layer dom_map
    html = root_node.render_to_html dom_map, true
    return html
  end
  
  def self.analyze(psd_json_data)
    layers = JSON.parse psd_json_data, :symbolize_names => true
    dom_map = self.get_dom_map layers
    html = self.generate_html dom_map
    html_fptr = File.new '/tmp/result.html', 'w+'
    html_fptr.write html
    html_fptr.close
    return true
  end
end