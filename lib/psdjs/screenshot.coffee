fs = require 'fs'
{PSD} = require './psd.js'

input_psd_file = process.argv[2]
output_png_file = process.argv[3]

console.log "Input psd file is #{input_psd_file}"
console.log "Output PNG file is #{output_png_file}"

psd = PSD.fromFile input_psd_file

psd.setOptions
  layerImages: false
  onlyVisibleLayers: true

start = (new Date()).getTime()

psd.toFileSync output_png_file

end = (new Date()).getTime()
console.log "PSD flattened to output.png in #{end - start}ms"

