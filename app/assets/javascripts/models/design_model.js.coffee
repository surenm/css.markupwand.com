class DesignModel extends Backbone.Model
  urlRoot: "/design"
  
  defaults:
    name: ""
    id: null
    
  initialize: () ->
    @grids = new GridCollection()
    @grids.fetch({data: {design: this.get("id")}, processData: true})

window.DesignModel = DesignModel