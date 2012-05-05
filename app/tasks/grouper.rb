class Grouper
  attr_accessor :nodes, :bounds

  private
  def remove_document_base
    self.nodes.delete_if do |node|
      node.bounds.top==self.bounds.top and node.bounds.bottom==self.bounds.bottom and node.bounds.right==self.bounds.right and node.bounds.left==self.bounds.left
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
        node_bounds = node_json["bounds"]["value"]
        bounding_box = BoundingBox(node_bounds["top"]["value"], node_bounds["left"]["value"], node_bounds["bottom"]["value"], node_bounds["right"]["value"])
        node = DesignNode.new(bounding_box)
        self.nodes.push node
      end
      bounding_boxes = nodes.collect {|node| node.bounds}
      self.bounds = BoundingBox.get_super_bounds bounding_boxes
      remove_document_base
    end
  end
