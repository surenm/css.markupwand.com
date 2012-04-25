require "pp"

class Analyzer
  def self.analyze(psd_json_data)
    layers = JSON.parse psd_json_data, :symbolize_names => true
    bounding_rectangles = layers.collect do |layer|
      PhotoshopItem::LayerBounds.new(layer[:bounds])
    end
    pp bounding_rectangles
    return true
  end
end