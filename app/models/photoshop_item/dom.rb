require "pp"

class PhotoshopItem::Dom
  include ActionView::Helpers::TagHelper
  
  attr_accessor :top, :bottom, :left, :right, :children
  attr_reader :width, :height
  
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
  
  def self.create_dom(layers, grid, index)
    Log.debug "Creating DOM for #{layers[index].name}"
    
    children = []
    grid[index].each do |child_index|
      if grid[child_index].size > 0
        Log.debug "Adding a DOM layer #{layers[child_index].name}"
        children.push self.create_dom(layers, grid, child_index)
      else
        Log.debug "Adding a leaf layer #{layers[child_index].name}"
        children.push layers[child_index]
      end
    end
    PhotoshopItem::Dom.new layers[index], children, nil
  end
  
  def self.create_dom_from_psd(layer_objects)
     layers = layer_objects.collect do |layer_object|
       PhotoshopItem::Layer.new layer_object
     end

     layers.sort!

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
     
     dom = self.create_dom(layers, grid, root_index)    
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
    "Dom Node: (#{self.top}, #{self.left}) - #{self.width} wide, #{self.height} high - #{self.children.size}"
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
  
  def regroup!
    return if @children.empty?

    order = :down
    new_dom = @children
    begin
      if order == :down
        new_dom = regroup_downwards
        order = :left
      elsif order == :left
        new_dom = regroup_leftwards
        order = :down
      end
    end while false
  end
  
  def regroup_downwards
    @children.sort { |a, b| a.top <=> b.top }
    
=begin
      group = []
      dom_element = @children.first
      
      new_dummy_element = dom_element.clone
      new_dummy_element.right = new_dummy_element.left + width
            
      @children.each do |dom_element|
        if new_dummy_element.encloses? dom_element
          group.push dom_element
        end
      end
      
      group.each do |item|
        @children.delete item
      end
      
      new_dom.push group
      pp @children.size, @children.empty?
      pp new_dom
=end
    return
  end
  
  def regroup_leftwards
    return
  end
  
  def render_to_html
    html = ""
    Log.debug @ordering
    if @ordering == :left
      html = "<div>"
      @children.each do |child|
        html += child.render_to_html :css => { :float => 'left' }
      end
      html += "<div style='clear: both'></div>"
    else
      @children.each do |child|
        html += child.render_to_html
      end
    end
    return html
  end
end