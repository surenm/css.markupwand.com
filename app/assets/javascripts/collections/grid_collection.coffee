class GridCollection extends Backbone.Collection
  model: GridModel
  url: '/grids'
  
window.GridCollection = GridCollection