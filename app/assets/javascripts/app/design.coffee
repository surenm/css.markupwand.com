#= require_tree ../models
#= require_tree ../collections
#= require_tree ../views
#= require_tree ../routers

class DesignView extends Backbone.View
  el: "#design"
  initialize: ->
    

$(document).ready ->
  window.design = new DesignModel(design_data)
  design_view = new DesignView({model: window.design})