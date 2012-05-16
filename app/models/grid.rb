class Grid
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated  
  include ActionView::Helpers::TagHelper

  # self references for children and parent grids
  has_many :children, :class_name => 'Grid', :inverse_of => :parent
  belongs_to :parent, :class_name => 'Grid', :inverse_of => :children

  has_many :layers, :class_name => 'Layer'
  has_many :style_layers, :class_name => 'Layer'
  has_many :render_layers, :class_name => 'Layer'
  
  # fields relevant for a grid
  field :name, :type => String
  field :hash, :type => String
  field :orientation, :type => String, :default => :normal
  field :root, :type => Boolean, :default => false
  field :optimized, :type => Boolean, :default => false
  
  field :tag, :type => String, :default => :div
  field :override_tag, :type => String, :default => nil
  
  field :width_class, :type => String
  field :override_width_class, :type => String, :default => nil

  Grid::GROUPING_QUEUE = Queue.new
  
  def inspect
    self.id
  end
  
  def self.reset_grouping_queue
    Grid::GROUPING_QUEUE.clear
  end
  
  def self.group!
    while not Grid::GROUPING_QUEUE.empty?
      grid = Grid::GROUPING_QUEUE.pop
      grid.group!
    end
  end

  def self.get_vertical_gutters(bounding_boxes)
    vertical_lines = bounding_boxes.collect{|bb| bb.left}
    vertical_lines += bounding_boxes.collect{|bb| bb.right}
    vertical_lines.uniq!

    vertical_gutters = []
    vertical_lines.each do |vertical_line|
      is_gutter = true
      bounding_boxes.each do |bb|
        if bb.left < vertical_line and vertical_line < bb.right
          is_gutter = false
        end
      end
      vertical_gutters.push vertical_line if is_gutter
    end
    vertical_gutters.sort!
  end

  def self.get_horizontal_gutters(bounding_boxes)
    horizontal_lines = bounding_boxes.collect{|bb| bb.top}
    horizontal_lines += bounding_boxes.collect{|bb| bb.bottom}
    horizontal_lines.uniq!

    horizontal_gutters = []
    horizontal_lines.each do |horizontal_line|
      is_gutter = true
      bounding_boxes.each do |bb|
        if bb.top < horizontal_line and horizontal_line < bb.bottom
          is_gutter = false
        end
      end
      horizontal_gutters.push horizontal_line if is_gutter
    end
    horizontal_gutters.sort!
  end

  def self.get_grouping_boxes(layers)

    # All layer boundaries to get the gutters
    bounding_boxes = layers.collect {|layer| layer.bounds}
    
    # Get the vertical and horizontal gutters at this level
    vertical_gutters   = get_vertical_gutters bounding_boxes
    horizontal_gutters = get_horizontal_gutters bounding_boxes
    Log.debug "Vertical Gutters: #{vertical_gutters}"
    Log.debug "Horizontal Gutters: #{horizontal_gutters}"
    
    # if empty gutters, then there probably is no children here. 
    # TODO: Find out if this even happens?
    if vertical_gutters.empty? or horizontal_gutters.empty? 
      return []
    end
  
    # get all possible grouping boxes with the available gutters
    grouping_boxes = []
    
    trailing_horizontal_gutters = horizontal_gutters
    leading_horizontal_gutters = horizontal_gutters.rotate
    
    trailing_vertical_gutters = vertical_gutters
    leading_vertical_gutters = vertical_gutters.rotate
    
    horizontal_bounds = trailing_horizontal_gutters.zip leading_horizontal_gutters
    vertical_bounds = trailing_vertical_gutters.zip leading_vertical_gutters
    
    horizontal_bounds.slice! -1
    vertical_bounds.slice! -1    
    
    root_group = Group.new :normal
    horizontal_bounds.each do |horizontal_bound|
      row_group = Group.new :left
      vertical_bounds.each do |vertical_bound|
        row_group.push BoundingBox.new horizontal_bound[0], vertical_bound[0], horizontal_bound[1], vertical_bound[1]
      end
      root_group.push row_group
    end
    
    Log.debug root_group
    return root_group
  end

  # usually any layer that matches the grouping box's bounds is a style layer
  def self.get_style_layers(layers, parent_box = nil)
    style_layers = []
    if not parent_box.nil?
      
      if parent_box.class.to_s == "BoundingBox"
        max_bounds = parent_box
      else 
        max_bounds = parent_box.bounds
      end

      layers.each do |layer|
        if layer.bounds == max_bounds
          if layer.kind == Layer::LAYER_SOLIDFILL or layer.kind == Layer::LAYER_NORMAL
            style_layers.push layer
          end
        end
      end
    end
  
    style_layers.flatten!
    
    return style_layers
  end
  
  
  def set(layers, parent)
    layers.each { |layer| self.layers.push layer }

    self.parent = parent   # Parent grid for this grid
    
    if self.parent == nil
      Log.info "Setting the root node"
      self.root = true
      Grid::GROUPING_QUEUE.push self
    end
    
    if layers.empty?
      @bounds = nil
    else
      node_bounds = layers.collect {|layer| layer.bounds}
      @bounds = BoundingBox.get_super_bounds node_bounds
      width = @bounds.width
      if width <= 960
        self.width_class = PhotoshopItem::StylesHash.get_bootstrap_width_class width
      end
      self.layers.sort!
    end

    self.save!
  end
    
  def add_style_layers(grid_style_layers)
    if grid_style_layers.class.to_s == "Array"
      grid_style_layers.flatten!
      grid_style_layers.each { |style_layer| self.style_layers.push style_layer }
    else 
      self.style_layers.push grid_style_layers
    end
  end
    
  def group!
    if self.layers.size > 1
      children_subgrids = get_subgrids
      self.children.push children_subgrids
    elsif self.layers.size == 1
      Log.debug "Just one layer #{self.layers.first} is available. Adding to the grid"
      self.render_layers.push self.layers.first
    end
    self.save!
  end

  def get_subgrids
    Log.debug "Getting subgrids (#{self.layers.length} layers in this grid)"
    
    # Subgrids at this level
    subgrids = [] 
    
    # Some root grouping of nodes to recursivel add as children
    root_group = Grid.get_grouping_boxes self.layers
    Log.debug "Root groups #{root_group}"

    # list of layers in this grid.
    layers = self.layers
    initial_layers_count = layers.size
    available_nodes = Hash[layers.collect { |item| [item.uid, item] }]
        
    # Get all the styles nodes at this level. These are the nodes that enclose every other nodes in the group
    root_style_layers = Grid.get_style_layers layers, root_group
    Log.info "Root style layers are #{root_style_layers}" if root_style_layers.size > 0
    Log.debug "Root style layers are #{root_style_layers}"

    # First add them as style layers to this grid
    self.add_style_layers root_style_layers
    
    # next remove them from the available_layers to process
    Log.debug "Deleting #{root_style_layers} root style layers..."
    root_style_layers.each { |root_style_layer| available_nodes.delete root_style_layer.uid}

    root_group.children.each do |row_group|
      layers = available_nodes.values
      
      row_grid = Grid.new
      row_grid.set [], self
      
      row_grid.orientation = row_group.orientation
      row_layers = layers.select { |layer| row_group.bounds.encloses? layer.bounds }
      
      row_style_layers = Grid.get_style_layers row_layers, row_group
      Log.info "Row style layers are #{row_style_layers}" if row_style_layers.size > 0
      Log.debug "Row style layers are #{row_style_layers}" 
      
      # Add them to row grid style layers and remove from available_layers
      row_grid.add_style_layers row_style_layers
      
      Log.debug "Deleting #{row_style_layers} row style layers..."
      row_style_layers.each {|layer| available_nodes.delete layer.uid}
      
      row_group.children.each do |grouping_box|
        remaining_nodes = available_nodes.values
        Log.debug "Trying grouping box #{grouping_box}"
        nodes_in_region = BoundingBox.get_objects_in_region grouping_box, remaining_nodes, :bounds
        
        style_layers = Grid.get_style_layers remaining_nodes, grouping_box
        Log.info "Style layers are #{style_layers}" if style_layers.size > 0
        Log.debug "Style layers are #{style_layers}"
        
        if nodes_in_region.empty?
          Log.warn "Stopping, no more nodes in this region"
          # TODO: This grouping box denotes padding or white space between two regions. Handle that. 
          # Usually a corner case
        elsif nodes_in_region.size == initial_layers_count
          Log.warn "Stopping, no nodes were reduced"
          # TODO: This grouping_box is a superbound of thes nodes. 
          # Add this as a style to the grid if there exists a layer for this grouping_box
          # Sometimes there is no parent layer for this grouping box, when two big layers are interesecting for applying filters.
        elsif nodes_in_region.size < initial_layers_count
          Log.info "Recursing inside, found #{nodes_in_region.size} nodes in region"
          
          nodes_in_region.each {|node| available_nodes.delete node.uid}
          grid = Grid.new
          grid.set nodes_in_region, row_grid
          
          style_layers.each do |style_layer|
            Log.debug "Style node: #{style_layer.name}"
            grid.add_style_layers style_layer
            available_nodes.delete style_layer.uid
          end
          
          Grid::GROUPING_QUEUE.push grid
          row_grid.children.push grid
        end
        row_grid.save!
      end
      if row_grid.children.size == 1
        subgrid = row_grid.children.first
        subgrid.parent = self
        subgrids.push subgrid
      elsif row_grid.children.size > 1
        subgrids.push row_grid
      end
    end
    return subgrids
  end
  
  def tag
    if self.root
      :body
    else
      :div
    end
  end
  
  def to_html(args = {})
    #puts "Generating html for #{self.inspect}"
    css = args.fetch :css, {}
    
    self.style_layers.each do |layer|
      css.update layer.get_css({}, self.root)
    end
    
    css_class = PhotoshopItem::StylesHash.add_and_get_class Converter::to_style_string css
    
    if not self.width_class.nil?
      css_class = "#{css_class} #{self.width_class}"
    end

    # Is this required for grids?
    inner_html = args.fetch :inner_html, ''
  
    attributes = Hash.new
    attributes[:class] = css_class if not css_class.nil?
    
    children_override_css = Hash.new
    if self.orientation == :left
      children_override_css[:float] = 'left' 
    end

    sub_grid_args = Hash.new
    sub_grid_args[:css] = children_override_css
    
    self.render_layers.each do |layer|
      inner_html += layer.to_html sub_grid_args
    end
    
    self.children.each do |sub_grid|
      inner_html += sub_grid.to_html sub_grid_args
    end
    
    if not self.children.empty? and self.orientation == :left
      inner_html += content_tag :div, " ", { :style => "clear: both" }, false
    end
    
    html = content_tag tag, inner_html, attributes, false
    return html
  end
end
