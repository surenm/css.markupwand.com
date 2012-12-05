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
      :grouping_box => self.grouping_box.name,
      :style_rules => self.style_rules
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
    self.content[:positioned] == true
  end

  def orientation
    self.content[:orientation]
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
    return []
  end

  def positioned_siblings
    self.siblings.select { |sibling_grid| sibling_grid.positioned? }
  end

  def has_positioned_children?
    return self.positioned_children.size > 0
  end

  def has_positioned_siblings?
    return self.positioned_siblings > 0
  end

  def style_rules=(style_array)
    self.content[:style_rules] = style_array
  end

  def style_rules
    self.content[:style_rules]
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

  def has_shape_layers?
    shape_layers = false

    self.style_layers.each do |layer|
      if layer.type == Layer::LAYER_SHAPE
        shape_layers = true
      end
    end

    return shape_layers
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
      

      #border_width = self.get_border_width
      #if not border_width.nil?
      #  padding[:top]    -= border_width
      #  padding[:bottom] -= border_width
      #  padding[:left]   -= border_width
      #  padding[:right]  -= border_width
      #end
    end
    padding
  end

  
  def get_margin
    #TODO. Margin is not always from left and top. It is from all sides.

    margin = {:top => 0, :left => 0, :right => 0, :bottom => 0}

    if self.is_root?
      margin[:top]  += self.bounds.top
      margin[:left] += self.bounds.left
    else      
      # All grids are going to have a grouping box which contributes to margin
      margin_boxes = [self.grouping_box.bounds]

      # But only a few of them are going to have an offset box
      if not self.offset_box.nil?
        margin_boxes.push self.offset_box
      end

      margin_superbound   = BoundingBox.get_super_bounds margin_boxes

      margin[:top] = self.bounds.top - margin_superbound.top
      margin[:left] = self.bounds.left - margin_superbound.left
    end
    
    return margin
  end

  # Width subtracted by padding
  def unpadded_width
    width = 0
    padding = self.get_padding
    width = self.bounds.width - (padding[:left] + padding[:right])
    return width
  end

    # Height subtracted by padding
  def unpadded_height
    height = 0
    padding = self.get_padding
    height = self.bounds.height - (padding[:top] + padding[:bottom])
    return height
  end

  def get_min_height_and_width
    width = self.unpadded_width
    height = self.unpadded_height
    return {:'min-height' => "#{height}px", :'min-width' => "#{width}px"}
  end

  # If the width has already not been set, set the width
  def get_width
    width = self.unpadded_width

    if not width.nil? and width != 0
      return { :width => "#{width}px" }
    else
      return {}
    end
  end
  
  def get_height
    height = self.unpadded_height
    
    if not height.nil? and height != 0
      return :height => "#{height}px"
    else
      return {}
    end
  end

  def get_white_space
    margin  = self.get_margin
    padding = self.get_padding

    positions = [:top, :left, :bottom, :right]

    spacing = Hash.new

    if Utils::non_zero_spacing padding
      spacing[:padding] = "#{padding[:top]}px #{padding[:right]}px #{padding[:bottom]}px #{padding[:left]}px"
    end

    if Utils::non_zero_spacing margin
      spacing[:margin] = "#{margin[:top]}px #{margin[:right]}px #{margin[:bottom]}px #{margin[:left]}px"
    end

    return spacing
  end

  def layer_styles
    layer_styles = Array.new

    self.style_layers.each do |style_layer|
      layer_styles += style_layer.get_style_rules
    end

    if self.is_leaf?
      layer_styles += self.render_layer.get_style_rules
    end

    return layer_styles
  end

  def grouping_box_styles
    grouping_rules = Hash.new 

    # set margin, padding
    grouping_rules.update self.get_white_space
    
    # set width for the grid only if the parent is a left oriented grid
    if not self.parent.nil? and self.parent.orientation == Constants::GRID_ORIENT_LEFT
      grouping_rules.update self.get_width
    end
    
    # set height only if there are positioned children
    if self.has_positioned_children?
      grouping_rules.update self.get_height
    end
    
    # minimum height and width for shapes in style layers
    if self.has_shape_layers?
      grouping_rules.update self.get_min_height_and_width
    end

    return Compassify::styles_hash_to_array grouping_rules
  end

  def positioning_styles
    positioning_rules = Hash.new

    # If the grid is positioned absolutely then add absolute positioning styles
    if self.positioned?
      top = "#{self.bounds.top - self.parent.bounds.top + 1}px"
      left = "#{self.bounds.left - self.parent.bounds.left + 1}px"

      positioning_rules.update :position => 'absolute', :top => top, :left => left, :"z-index" => self.zindex
    else
      position_relatively = false
      if self.has_positioned_children?
        position_relatively = true
      end
      
      if position_relatively
        positioning_rules.update  :position => 'relative', :'z-index' => self.zindex
      end
    end

    return Compassify::styles_hash_to_array positioning_rules
  end

  def compute_styles
    #style_rules = self.layer_styles + self.positioning_styles + self.grouping_box_styles
    style_rules = self.positioning_styles + self.grouping_box_styles
    
    self.style_rules = style_rules.flatten
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
      attributes[:style] = self.style_rules.join ";"

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
      
      html = content_tag self.tag, inner_html, attributes, false
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
    "Orientation: #{self.orientation} GroupingBox: #{self.grouping_box.bounds} margin: #{self.offset_box}, style_layers: #{self.style_layers}"
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