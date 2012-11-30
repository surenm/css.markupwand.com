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
    if self.is_leaf?
      return (self.render_layer.tag_name == 'img')
    else
      return false
    end
  end

  def is_text_grid?
    if self.render_layer.nil?
      false
    else
      (self.render_layer.type == Layer::LAYER_TEXT)
    end
  end

  

  ##########################################################
  # STYLE CALCULATIONS METHODS
  ##########################################################
  def get_border_width
    border_width = nil
    if self.computed_css.has_key? :border
      border_properties = self.computed_css.fetch(:border).split
      border_width_str = border_properties[0].scan(/\d+/).first
      if not border_width_str.nil?
        border_width = border_width_str.to_i
      end
    end
    return border_width
  end

  def get_padding
    non_style_layers = self.layers - self.style_layers
    
    children_bounds = non_style_layers.collect { |layer| layer.bounds }
    children_superbound = BoundingBox.get_super_bounds children_bounds
    padding = { :top => 0, :left => 0, :bottom => 0, :right => 0 }
    
    if not self.bounds.nil? and not children_superbound.nil?
      padding[:top]    = (children_superbound.top  - self.bounds.top)
      padding[:bottom] = (self.bounds.bottom - children_superbound.bottom)
      padding[:left]   = (children_superbound.left - self.bounds.left) 
      padding[:right]  = (self.bounds.right - children_superbound.right)
      

      border_width = self.get_border_width
      if not border_width.nil?
        padding[:top]    -= border_width
        padding[:bottom] -= border_width
        padding[:left]   -= border_width
        padding[:right]  -= border_width
      end
    end
    padding
  end

  
  def get_margin
    #TODO. Margin is not always from left and top. It is from all sides.

    margin = {:top => 0, :left => 0}
    if self.is_root?
      margin[:top]  += self.grid.bounds.top
      margin[:left] += self.grid.bounds.left
    else
      
      margin_boxes = []

      if not self.offset_box.nil?
        margin_boxes.push self.grid.offset_box
      end

      if not self.grid.grouping_box.nil?
        margin_boxes.push self.grouping_box.bounds
      end      
      
      if not margin_boxes.empty?
        children_bounds     = self.layers.collect { |layer| layer.bounds }
        children_superbound = BoundingBox.get_super_bounds children_bounds        
        margin_superbound   = BoundingBox.get_super_bounds margin_boxes
           
        if not margin_superbound.nil? and not children_superbound.nil?
          margin[:top] = children_superbound.top - margin_superbound.top
          margin[:left] = children_superbound.left - margin_superbound.left
        end
      end
    end
    
    return margin
  end

  # Width subtracted by padding
  def unpadded_width
    width = 0

    if not self.bounds.nil?
      padding = self.get_padding

      width += self.bounds.width
      width -= padding[:left] + padding[:right]
      
    end
    return width
  end

    # Height subtracted by padding
  def unpadded_height
    height = 0

    if not self.bounds.nil?
      padding = self.get_padding

      height += self.bounds.height
      height -= padding[:top] + padding[:bottom]
    end
    return height
  end

  # If the width has already not been set, set the width
  def set_width
    width = self.unpadded_width

    if not width.nil? and width != 0
      return { :width => width.to_s + 'px' }
    else
      return {}
    end
  end
  
  def set_height
    height = self.unpadded_height
    
    if not height.nil? and height != 0
      return :height => height.to_s + "px"
    else
      return {}
    end
  end

  def set_min_dimensions
    width = self.unpadded_width
    height = self.unpadded_height
    return { :'min-height' => "#{height}px", :'min-width' => "#{width}px" }
  end

  def positioning_rules
    position_relatively = false
    if self.has_positioned_children?
      position_relatively = true
    end
    
    if not self.is_root?
      if self.parent.computed_css.has_key? 'position' and parent.style.computed_css.fetch('position') == 'relative'
        position_relatively = true
      elsif parent.positioned?
        position_relatively = true
      end
    end

    if position_relatively
      style_rules.update  :position => 'relative', :'z-index' => self.grid.zindex
    end
  end

  def compute_styles

  end


  ##########################################################
  # HTML METHODS
  ##########################################################
  def positioned_grids_html(subgrid_args = {})
    html = ''
    self.children.each do |grid|
      if grid.positioned?
        html += grid.to_html(subgrid_args)
      end
    end
    html
  end

  def to_html(args = {})
    Log.info "[HTML] #{self.to_s}"
    html = ''
    
    # Is this required for grids?
    inner_html = args.fetch :inner_html, ''
  
    attributes = Hash.new

    if not self.is_leaf?

      attributes[:class] = self.style.selector_names.join(" ") if not self.style.selector_names.empty?
 
      sub_grid_args = Hash.new
      positioned_html = positioned_grids_html sub_grid_args
      if not positioned_html.empty?
        inner_html += content_tag :div, '', :class => 'marginfix'
      end
      
      child_nodes = self.children.select { |node| not node.positioned? }
      child_nodes.each do |sub_grid|
        inner_html += sub_grid.to_html sub_grid_args
      end

      inner_html += positioned_html
      
      if child_nodes.length > 0
        html = content_tag self.tag, inner_html, attributes, false
      end
      
    else
      sub_grid_args      = attributes
      sub_grid_args[tag] = self.tag

      sub_grid_args[:inner_html] = self.positioned_grids_html

      inner_html  += self.render_layer.to_html sub_grid_args
      

      if self.render_layer.tag_name == 'img'
        html = content_tag 'div', inner_html, {}, false
      else 
        html = inner_html
      end
    end
    
    return html
  end

  ##########################################################
  # DEBUG METHODS
  ##########################################################

  def to_s
    "#{self.orientation} GroupingBox: #{self.grouping_box.bounds} margin: #{self.offset_box}, style_layers: #{self.style_layers}"
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