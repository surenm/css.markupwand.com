class Grouper
  attr_accessor :nodes

  private
  def objectify(nodes_json)
    nodes_json.each do |node_json|
      node = {}
      node_bounds = node_json["bounds"]["value"]
      node["top"] = node_bounds["top"]["value"]
      node["bottom"] = node_bounds["bottom"]["value"]
      node["left"] = node_bounds["left"]["value"]
      node["right"] = node_bounds["right"]["value"]
      @nodes.push node
    end
    set_bounding_box
  end

  def reset_bounding_box
    @min_top = @min_left = @max_bottom = @max_right = nil
  end

  def set_bounding_box
    reset_bounding_box
    @nodes.each do |node|
      if @min_top.nil? or node["top"]<@min_top
        @min_top = node["top"]
      end
      if @min_left.nil? or node["left"]<@min_left
        @min_left = node["left"]
      end
      if @max_bottom.nil? or node["bottom"]>@max_bottom
        @max_bottom = node["bottom"]
      end
      if @max_right.nil? or node["right"]>@max_right
        @max_right = node["right"]
      end
    end
    puts "#{@min_top}|#{@min_left}|#{@max_bottom}|#{@max_right}"
  end

  def remove_document_base
    puts @nodes.size
    puts "#{@min_top}|#{@min_left}|#{@max_bottom}|#{@max_right}"
    @nodes.delete_if do |node|
      node["top"]==@min_top and node["bottom"]==@max_bottom and node["right"]==@max_right and node["left"]==@min_left
    end
    puts @nodes.size
    set_bounding_box
  end

  public
  def initialize
    @nodes = []
    @min_top = nil
    @min_left = nil
    @max_bottom = nil
    @max_right = nil
  end

  def load_from_json(json_file)
    fh = File.read json_file
    json = JSON.parse fh
    objectify json
    remove_document_base
  end

  def bounding_box
    bb = {}
    bb["top"] = @min_top
    bb["bottom"] = @max_bottom
    bb["right"] = @max_right
    bb["left"] = @min_left
    return bb
  end
end
