require 'erb'

class StyleNode
  #TODO: Style rules ideally needs to be a hash no?
  attr_accessor :style_rules # Array of style rules. 


  attr_accessor :children # Array of StyleNodes
  
  # One of them is a must, multiple items could be present
  attr_accessor :style_class # Style class name
  attr_accessor :style_id # Style identifier
  attr_accessor :style_tag # Style HTML tag
  
  SCSS_TEMPLATE = ERB.new  <<-SCSS
.<%= @style_class %> {
<% @style_rules.each do |style_rule| %>\
<%= style_rule %>;
<% end %>\
<% @children.each do |child| %>\
<%= child.to_scss %>
<% end %>\
}
SCSS
  
  def initialize(args)
    # TODO: For now assuming only class name comes in. Handle tag and id
    @style_class = args.fetch :class, ""
    @style_rules = args.fetch :style_rules, []
    @children    = args.fetch :children, []
  end
  
  def attribute_data
    {
      :class     => @style_class,
      :css_rules => @style_rules,
      :children  => @children
    }
  end
  
  def to_scss
    result = SCSS_TEMPLATE.result binding
  end
end