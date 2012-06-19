module Utils
  def Utils::strip_unwanted_attrs_from_html(html)
    dom = Nokogiri::HTML::Document.parse html
    Utils.strip_unwanted_attrs_from_dom dom
    return dom.serialize
  end
  
  def Utils::strip_unwanted_attrs_from_dom(dom)
    data_attributes = ['data-grid-id', 'data-layer-id', 'data-layer-name', 'enable_data_attributes', 'tag']
    dom.children.each do |child_dom|
      data_attributes.each do |attribute|
        attributes = child_dom.remove_attribute attribute if child_dom.attributes.has_key? attribute
      end
      Utils.strip_unwanted_attrs_from_dom child_dom
    end
  end
end