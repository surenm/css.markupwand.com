class Grouper
  attr_accessor :nodes, :bounds

  private
  def find_bounds
    top = left = bottom = right = nil
    self.nodes.each do |node|
      if top.nil? or node["top"]<top
        top = node["top"]
      end
      if left.nil? or node["left"]<left
        left = node["left"]
      end
      if bottom.nil? or node["bottom"]>bottom
        bottom = node["bottom"]
      end
      if right.nil? or node["right"]>right
        right = node["right"]
      end
    end
    return BoundingBox.new(top, left, bottom , right)
  end

  def remove_document_base
    self.nodes.delete_if do |node|
      node["top"]==self.bounds.top and node["bottom"]==self.bounds.bottom and node["right"]==self.bounds.right and node["left"]==self.bounds.left
    end
    self.bounds = find_bounds
  end
  
  def order_boxes
    @bounds.each do 
  end

  public
  def initialize(json_file)
    self.nodes = []
    fh = File.read json_file
    json = JSON.parse fh
    json.each do |node_json|
      node = {}
      node_bounds = node_json["bounds"]["value"]
      node["top"] = node_bounds["top"]["value"]
      node["bottom"] = node_bounds["bottom"]["value"]
      node["left"] = node_bounds["left"]["value"]
      node["right"] = node_bounds["right"]["value"]
      self.nodes.push node
    end
    self.bounds = find_bounds
    remove_document_base
  end
end
