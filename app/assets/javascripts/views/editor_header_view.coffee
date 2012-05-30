class EditorHeaderView extends Backbone.View
  initialize: (args) ->
    this.render()
    
  events: {
    "click #update-markup": "click_handler"
  }
    
  render: () ->
    template_string = $("#editor-header-template").html()
    template_context = this.model.toJSON() if this.model?
    html = _.template(template_string, template_context)
    
    $(this.el).html html
  
  click_handler: (event) ->
    try 
      console.log this.options.design
      $.post(
        '/grids/update', 
        design: this.options.design
        (data, status, jqXHR) ->
          console.log data    
      )
    catch error
      console.log error

    
    # return false to the link so that it doesn't go anywhere
    return false

window.EditorHeaderView = EditorHeaderView