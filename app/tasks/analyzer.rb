require "pp"

class Analyzer  
  
  def self.analyze(psd_json_data)
    psd_layers = JSON.parse psd_json_data, :symbolize_names => true
    
    Log.info "Beginning analyzing..."
    raw_dom = PhotoshopItem::Dom.create_dom_from_psd psd_layers
    dom = PhotoshopItem::Dom.regroup raw_dom

    Log.info "Generating HTML..."
    html = dom.render_to_html
    html_fptr = File.new '/tmp/result.html', 'w+'
    html_fptr.write html
    html_fptr.close
    return
  end
end
