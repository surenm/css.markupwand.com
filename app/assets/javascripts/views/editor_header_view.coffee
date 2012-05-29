class EditorHeaderView extends Backbone.View
  initialize: (args) ->
    this.render()
    
  render: () ->
    template_string = $("#editor-header-template").html()
    template_context = this.model.toJSON() if this.model?
    html = _.template(template_string, template_context)
    
    $(this.el).html html

window.EditorHeaderView = EditorHeaderView