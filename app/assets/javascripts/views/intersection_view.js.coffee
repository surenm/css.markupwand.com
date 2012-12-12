class IntersectionView extends Backbone.View
  el: "#app"
  left_sidebar: "#left-sidebar"
  right_sidebar: "#right-sidebar"
 
  initialize: ->
    this.render()

  render: ->
    console.log "hi"


window.IntersectionView = IntersectionView