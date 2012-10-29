
class SidebarView extends GenericView
  design_sidebar_templates: {
    default     : "#design-default-template"
    identifiers : "#design-edit-identifiers-template",
    classes     : "#design-edit-classes-template",
    tags        : "#design-edit-tags-template"
  }
  grid_sidebar_template: "#grid-sidebar-template"
  el: "#editor"

  events: {
    "click .grid-sidebar .show": "editGrid"
    "click .grid-sidebar #success": "onSuccess"
    "click .grid-sidebar #cancel": "onCancel"
    "click .grid-sidebar #done": "onClose"
    
    "click .design-classes .css-class": "editDesignClass"
  }

  initialize: () ->
    this.options.context = "default" if not this.options.context?

    this.render()
    
  render: () ->
    if this.model instanceof GridModel
      this.render_grid_sidebar()
    else if this.model instanceof DesignModel
      this.render_design_sidebar()
      
  render_design_sidebar: () ->
    template_id = this.design_sidebar_templates[this.options.context]
    template_string = $(template_id).html()
    template_context = this.model.toJSON()
    html = _.template(template_string, template_context)

    $(this.el).html html

  render_grid_sidebar: () ->
    template_string = $(this.grid_sidebar_template).html()
    template_context = this.model.toJSON()
    html = _.template(template_string, template_context)
    
    $(this.el).html html
    
  editGrid: (event) ->
    $(this.el).find(".form").show()
    $(this.el).find(".show").hide()
    
  onSuccess: (event) ->
    $editor = app.editor_iframe
    $editor.show_loading()
    
    tag = $(this.el).find("#taginput").attr("value")
    this.model.set "tag", tag
    this.model.save({},{
      success: () ->
        app.editor_iframe.reload()
    })
    this.render()

  onCancel: (event) -> 
    $(this.el).find(".form").hide()
    $(this.el).find(".show").show()
  
  onClose: (event) ->
    event.stopPropagation()
    app.editor_iframe.release_focus()

    # if the current model is GridModel then we have to load back the design sidebar
    if this.model instanceof GridModel
      app.load_design_sidebar()
      
  editDesignClass: (event) ->
    selected_obj = event.target
    classname = $(selected_obj).data('styleClass')
    grids = app.design.get("css_classes")[classname]
    $editor_iframe = app.editor_iframe
    $.each grids, (index, value) ->
      grid = $editor_iframe.iframe_dom.find("[data-grid-id=#{value}]")
      $.each grid, () ->
        $editor_iframe.focus_selected_object this

window.SidebarView = SidebarView