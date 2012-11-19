class BoundingBox
  @get_super_bounds: (bounding_boxes) ->
    top = left = bottom = right = null
    for bounding_box in bounding_boxes 
      if not top? or bounding_box.top < top
        top = bounding_box.top
      
      if not left? or bounding_box.left < left
        left = bounding_box.left
      
      if not bottom? or bounding_box.bottom > bottom
        bottom = bounding_box.bottom
      
      if not right? or bounding_box.right > right
        right = bounding_box.right

    return {top: top, bottom: bottom, right: right, left: left}

window.BoundingBox = BoundingBox