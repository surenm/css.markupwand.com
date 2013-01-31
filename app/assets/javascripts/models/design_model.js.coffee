class DesignModel extends Backbone.Model
  urlRoot: "/design"

  initialize: (design_data) ->
    @layers = new LayerCollection()
    @grouping_boxes = new GroupingBoxCollection()

    $design = this
    
    # Reset collections is design is ready
    if this.is_ready()
      this.reset_collection_data()
    else  
      $.doTimeout 100, () ->
        $design.fetch()

    # everytime the model changes, if the design is ready to be rendered, reset collection data
    this.on "change", () ->
      if this.is_ready() 
        this.reset_collection_data()

    this.on "sync", () ->
      if not this.is_ready()
        console.log "still processing..."
        $.doTimeout 1000, () ->
          $design.fetch()
      else
        window.location.reload()

  reset_collection_data: () ->
    sif_data = this.get('sif')
    @layers.reset sif_data['layers']
    @grouping_boxes.reset sif_data['grouping_boxes']

  get_bounds: () ->
    bounds = 
      top: 0
      left: 0
      bottom: this.get('height') 
      right: this.get('width')

  get_assets_root: ->
    return "/extracted/#{this.get('safe_name')}/images"

  get_images_rename_url: ->
    return "/design/#{this.get('safe_name')}/image-rename"

  get_layer: (layer_id) ->
    return @layers.get(layer_id)

  get_grouping_box: (grouping_box_id) ->
    return @grouping_boxes.get(grouping_box_id)

  is_ready: () ->
    return (this.get('status') == 'extracting_done') and (this.get('photoshop_status') == 'processing_done')


window.DesignModel = DesignModel