class GridCollection extends Backbone.Collection
  model: Grid
  url: '/grids'
  
window.GridCollection = GridCollection