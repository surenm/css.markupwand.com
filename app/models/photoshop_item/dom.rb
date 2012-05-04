require "pp"

class PhotoshopItem::Dom
  
  attr_accessor :top, :bottom, :left, :right, :children
  attr_reader :width, :height
  
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
    
    @top = Constants::INF
    @bottom = -Constants::INF
    @left = Constants::INF
    @right = -Constants::INF
    
    fix_bounds
  end

  def <=>(other_layer)
    if self.top == other_layer.top
      return self.left <=> other_layer.left
    else
      return self.top <=> other_layer.top
    end
  end
  
  def inspect
    s = "Dom Node: (#{self.top}, #{self.left}::#{self.bottom}, #{self.right}) - #{self.width} wide, #{self.height} high with order #{@ordering}\n"
    @children.each do |child|
      s += child.inspect
    end
    
    s
  end
  
  def encloses?(other_layer)
    return (self.top <= other_layer.top and self.left <= other_layer.left and self.bottom >= other_layer.bottom and self.right >= other_layer.right)
  end
  
  def intersect?(other)
    return (self.left < other.right and self.right > other.left and self.top < other.bottom and self.bottom > other.top)
  end
  
  def fix_bounds
    @children.each do |child|
      @top    = [child.top, @top].min
      @bottom = [child.bottom, @bottom].max
      @left   = [child.left, @left].min
      @right  = [child.right, @right].max
    end

    @width  = @right - @left
    @height = @bottom - @top
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
    dom.children.sort { |a, b| a.top <=> b.top }
    
    current_dom = dom
    new_dom = PhotoshopItem::Dom.new nil, [], :down
    begin
      # chose the topmost child
      first_element = current_dom.children.first
      dummy_element = first_element.clone 
      
      dummy_element.right = dummy_element.left + dom.width
      
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