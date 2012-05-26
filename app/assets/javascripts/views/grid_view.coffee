class GridView extends Backbone.View
  
  render: () ->
    template_string = $("#edit-grid-properties-template").html()
    html = _.template(template_string, this.model.toJSON());
    $(this.el).html html

window.GridView = GridView