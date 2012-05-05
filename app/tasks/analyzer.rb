require "pp"

class Analyzer  
  
  def self.analyze(psd_json_data)
    psd_data = JSON.parse psd_json_data, :symbolize_names => true
    
    Log.info "Beginning analyzing..."
    raw_dom = PhotoshopItem::Dom.create_dom_from_psd psd_data
    dom = PhotoshopItem::Dom.regroup raw_dom

    Log.info "Generating HTML..."
    body_html = dom.render_to_html
    wrapper   = File.new Rails.root.join('app','assets','wrapper_templates','bootstrap_wrapper.html'), 'r'
    html      = wrapper.read
    wrapper.close
    
    html.gsub! "{yield}", body_html

    return html
  end
end
