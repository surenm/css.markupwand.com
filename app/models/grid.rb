class Grid < Tree::TreeNode
  include ActionView::Helpers::TagHelper

  def initialize(args)
    @id = args.fetch :id, self.unique_identifier(args[:layers])
    super @id, args

  end

  def unique_identifier(layers)
    layer_uids = layers.collect { |layer| layer.uid }
    raw_identifier = "#{layer_uids.join '-'}"
    digest = Digest::MD5.hexdigest raw_identifier
    return digest
  end

  def attribute_data
    children_tree = []
    self.children.each do |child|
      children_tree.push child.attribute_data
    end

    layer_ids       = self.layers.collect { |layer| layer.uid }
    style_layer_ids = self.style_layers.collect { |style_layer| style_layer.uid }
    
    offset_box_data = self.offset_box.attribute_data if not self.offset_box.nil?
    
    attr_data = {
      :id => @id,
      :layers => layer_ids,
      :children => children_tree,
      :style_layers => style_layer_ids,
      :positioned => self.positioned?,
      :orientation => self.orientation,
      :offset_box => offset_box_data,
      :grouping_box => self.grouping_box.name
    }   

    return Utils::prune_null_items attr_data
  end

  ##########################################################
  #  GRID OBJECT HELPERS
  ##########################################################
  def id
    self.content[:id]
  end

  def layers
    self.content[:layers]
  end

  def style_layers
    self.content[:style_layers]
  end

  def render_layer
    self.layers.first
  end

  def positioned?
    self.content[:positioned]
  end

  def orientation
    self.content[:orientation]
  end

  def tag
    self.content[:tag]
  end

  def grouping_box
    self.content[:grouping_box]
  end

  def offset_box=(bounding_box)
    self.content[:offset_box] = bounding_box
  end

  def offset_box
    self.content[:offset_box]
  end

  def positioned_children
    self.children.each { |child_grid| child_grid.positioned? }
  end

  def positioned_siblings
    self.siblings.each { |sibling_grid| sibling_grid.positioned? }

  end

  def has_positioned_children?
    return self.positioned_children.size > 0
  end

  def has_positioned_siblings?
    return self.positioned_siblings > 0
  end

  def style=(style_object)
    self.content[:style] = style_object
  end

  def style
    self.content[:style]
  end

  def bounds
    if self.layers.empty?
      bounds = nil
    else
      layers_bounds = self.layers.collect {|layer| layer.bounds}
      bounds = BoundingBox.get_super_bounds layers_bounds
    end
    return bounds
  end
  
  def zindex
    zindex = 0
    
    all_layers_z_indices = []
    self.layers.each do |layer|
      all_layers_z_indices.push layer.zindex
    end

    grid_zindex = all_layers_z_indices.min
    
    return grid_zindex
  end
  
  def tag
    if @tag.nil?
      if self.is_image_grid?
        @tag = 'img'
      else
        @tag = 'div'
      end
    end

    return @tag
  end
  
  def is_image_grid?
    if not self.render_layer.nil?
      false
    else 
      return (self.render_layer.tag_name == 'img')
    end
  end

  def is_text_grid?
    if self.render_layer.nil?
      false
    else
      (self.render_layer.type == Layer::LAYER_TEXT)
    end
  end
  
  def to_s
    "#{self.orientation} #{self.grouping_box.bounds} margin: #{self.offset_box}, style_layers: #{self.style_layers}"
  end

  def print_tree(level = 0)
    if is_root?
      print "*"
    else
      print "|" unless parent.is_last_sibling?
      print(' ' * (level - 1) * 4)
      print(is_last_sibling? ? "+" : "|")
      print "---"
      print(has_children? ? "+" : ">")
    end

    puts "#{self.to_s}"

    children { |child| child.print_tree(level + 1)}
  end
end