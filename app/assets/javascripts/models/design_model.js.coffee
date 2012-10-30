class DesignModel extends Backbone.Model
  urlRoot: "/design"
  
  initialize: () ->
    console.log this.attributes

window.DesignModel = DesignModel