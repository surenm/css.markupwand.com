class GridCollection extends Backbone.Collection
  model: GridModel
  url: '/grids'

class StyleCollection extends Backbone.Collection
  model: StyleModel
  
window.GridCollection = GridCollection