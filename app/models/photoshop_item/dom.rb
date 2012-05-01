require "pp"

class PhotoshopItem::Dom
  include ActionView::Helpers::TagHelper
  
  attr_accessor :top, :bottom, :left, :right, :children
  attr_reader :width, :height
  
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
     
     grid_data = Array.new
     grid.each do |grid_row|
       grid_row_data = Array.new
       grid_row.each do |layer_index|
         grid_row_data.push layers[layer_index]
       end
       
       # TODO: This might skip few independent layers. Add them as well.
       if not grid_row_data.empty?
         row_dom = PhotoshopItem::Dom.new grid_row_data
         grid_data.push row_dom
       end
     end

     dom = PhotoshopItem::Dom.new grid_data, :down
     return dom
   end
  
  def initialize(children, ordering = nil)
    @children = children
    
    @top = Constants::INF
    @bottom = -Constants::INF
    @left = Constants::INF
    @right = -Constants::INF
    
    fix_bounds
    regroup!
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
    @children.each do |child|
      html += child.render_to_html
    end
    return html
  end
end