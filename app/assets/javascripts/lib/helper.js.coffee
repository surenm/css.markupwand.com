class Helper
  @get_value_from_pixel_string: (pixel_string) ->
    tokens = pixel_string.split 'p'
    return parseInt(tokens[0])

window.Helper = Helper