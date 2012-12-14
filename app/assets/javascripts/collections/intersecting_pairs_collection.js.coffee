class IntersectingPairsCollection extends Backbone.Collection
  initialize: (design)->
    this._attributes = {}

  model: IntersectingPairsModel,
  attr: (prop, value)->
    if value == undefined
      this._attributes[prop]
    else
      this._attributes[prop] = value

  url: ()->
    '/design/' + this.attr('design_id') + '/intersecting-pairs'  

window.IntersectingPairsCollection = IntersectingPairsCollection