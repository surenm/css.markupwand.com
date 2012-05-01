require "pp"

class Analyzer  
  def self.generate_html(dom)
    html = dom.render_to_html
    return html
  end
  
  def self.analyze(psd_json_data)
    psd_layers = JSON.parse psd_json_data, :symbolize_names => true

    dom = PhotoshopItem::Dom.create_dom_from_psd psd_layers
      
    html = self.generate_html dom
    html_fptr = File.new '/tmp/result.html', 'w+'
    html_fptr.write html
    html_fptr.close
    return true
  end
end
