class GenericView extends Backbone.View
  render: () ->
    template_string = $(this.template).html()
    template_context = this.model.toJSON()
    html = _.template(template_string, template_context)
    
    $(this.el).html html
  
  close: () ->
    $(this.el).unbind()
    $(this.el).empty()

window.GenericView = GenericView