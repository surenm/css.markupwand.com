class GridView extends Backbone.View
  
  render: () ->
    template_string = $("#edit-grid-properties-template").html()
    template_context = this.model.toJSON()
    html = _.template(template_string, template_context);
    $(this.el).html html

window.GridView = GridView