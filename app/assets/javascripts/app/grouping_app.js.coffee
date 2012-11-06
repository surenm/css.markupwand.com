#= require_tree ../models
#= require_tree ../collections
#= require_tree ../views
#= require_tree ../routers

class GroupingApp
  constructor: () ->
    # design_data and sif_data are defined in import.html.erb
    @design = new DesignModel(design_data, sif_data)

  load_grouping_view: ->
    @grouping_view = new GroupingView
    
    
$(document).ready ->
  window.app = new GroupingApp()
  window.app.load_grouping_view()