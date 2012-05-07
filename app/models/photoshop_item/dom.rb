require "pp"

class PhotoshopItem::Dom
  
  attr_accessor :bounds, :children
  
  #TODO: This is a hack. Fix this
  def self.get_root(grid)
    max_possible = grid.size
    ret = -1
    max = -1
    grid.each_with_index do |row, index|
      if row.size == max_possible
        return index
      elsif row.size > max
        max = row.size
        ret = index
      end
    end
    return ret
  end
  
  def self.create_dom(layers, grid, index, ordering = nil)
    Log.info "Creating DOM for #{layers[index].name} with ordering #{ordering}"
    
    children = []
    grid[index].each do |child_index|
      if grid[child_index].size > 0
        Log.debug "Adding a DOM layer #{layers[child_index].name}"
        children.push self.create_dom layers, grid, child_index
      else
        Log.debug "Adding a leaf layer #{layers[child_index].name}"
        children.push layers[child_index]
      end
    end
    PhotoshopItem::Dom.new layers[index], children, ordering
  end
  
  def self.create_dom_from_psd(psd_data)
    layers_json = psd_data[:art_layers]
    layers = []
    layers_json.each do |key, layer_object|
      layer = PhotoshopItem::Layer.new layer_object
      layers.push layer
    end

    layers.sort!
    Log.info "Total #{layers.size} layers available"

    # Find a grid map of enclosing rectangles
    # grid[i][j] is true if i-th rectangle encloses j-th rectangle
    layers_count = layers.size
    grid = Array.new(layers_count) { Array.new }
    for i in 0..(layers_count-1)
      for j in 0..(layers_count-1)
        first = layers[i]
        second = layers[j]
        if i != j and first.encloses? second
          grid[i].push j
        end
      end
    end

    root_index = self.get_root(grid)
    Log.info "Root: #{layers[root_index].name}"

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

    dom = self.create_dom layers, grid, root_index, :down
    return dom
  end
  
  def initialize(layer, children, ordering = nil)
    @layer = layer
    @children = children
    @ordering = ordering
    
    top = Constants::INF
    bottom = -Constants::INF
    left = Constants::INF
    right = -Constants::INF
    
    @bounds = BoundingBox.new(top, left, bottom, right)
    
    fix_bounds
  end

  def <=>(other_layer)
    self.bounds <=> other_layer.bounds
  end
  
  def inspect
    s = "Dom Node: (#{self.top}, #{self.left}::#{self.bottom}, #{self.right}) - #{self.width} wide, #{self.height} high with order #{@ordering}\n"
    @children.each do |child|
      s += child.inspect
    end
    
    s
  end
  
  def encloses?(other_layer)
    self.encloses? other_layer
  end
  
  def intersect?(other)
    self.intersect?other
  end
  
  def fix_bounds
    top = bottom = left = right = nil
    @children.each do |child|
      top    = [child.bounds.top, @bounds.top].min
      bottom = [child.bounds.bottom, @bounds.bottom].max
      left   = [child.bounds.left, @bounds.left].min
      right  = [child.bounds.right, @bounds.right].max
    end
    @bounds = BoundingBox.new(top, left, bottom, right)
  end
  
  def self.regroup(dom)
    return if dom.children.empty?
    Log.debug "Regrouping..."
    new_dom = regroup_downwards dom

    #order = :down
    #new_dom = @children
    #begin
    #  if order == :down
    #    new_dom = regroup_downwards
    #    order = :left
    #  elsif order == :left
    #    new_dom = regroup_leftwards
    #    order = :down
    #  end
    #end while false
    return new_dom
  end
  
  def add_dom_or_layer(item)
    @children.push item
    
    fix_bounds
  end
  
  def self.regroup_downwards(dom)
    Log.debug "Regrouping downwards..."
    dom.children.sort { |a, b| a.bounds.top <=> b.bounds.top }
    
    current_dom = dom
    new_dom = PhotoshopItem::Dom.new nil, [], :down
    begin
      # chose the topmost child
      first_element = current_dom.children.first
      dummy_element = first_element.clone 
      
      dummy_element.bounds.right = dummy_element.bounds.left + dom.bounds.width
      
      grouped_elements = []
      current_dom.children.each do |element|
        if dummy_element.intersect? element
          grouped_elements.push element
        end
      end
      
      grouped_elements.each do |element|
        current_dom.children.delete element
      end
      
      if grouped_elements.size > 1
        new_group_dom = PhotoshopItem::Dom.new nil, grouped_elements, :left
        new_dom.add_dom_or_layer new_group_dom
      else
        new_dom.add_dom_or_layer first_element
      end
    end while not current_dom.children.empty?
    return new_dom
  end
  
  def regroup_leftwards
    return
  end
  
  def render_to_html(args = nil)
    html = ""

    if @ordering == :left
      html = "<div>"
      @children.each do |child|
        html += "<div style='float:left'> #{child.render_to_html} </div>"
      end
      html += "<div style='clear: both'></div></div>"
    else
      @children.each do |child|
        html += child.render_to_html
      end
    end
    return html
  end
end