class Utils
  def self.process_test_file
    self.process_file "/tmp/mailgun.psd.json"
  end
  
  def self.process_file(file_name)
    Log.info "Beginning to process #{file_name}..."

    fptr     = File.read file_name
    psd_data = JSON.parse fptr, :symbolize_names => true
    
    # A hash of all layers
    art_layers = psd_data[:art_layers]
    layer_sets = psd_data[:layer_sets]  


    # Initialize styles hash and font map
    font_map    = PhotoshopItem::FontMap.new art_layers
    font_map.find_web_fonts
    
    styles_hash = PhotoshopItem::StylesHash.new font_map
    
    # Layer descriptors of all photoshop layers
        
    Log.info "Getting nodes..."
    nodes = []
    art_layers.each do |layer_id, node_json|
      node = PhotoshopItem::Layer.new(node_json)
      nodes.push node
    end
    
    Grid.reset_grouping_queue
    
    Log.info "Creating grids..."
    grid = Grid.new nodes, nil
    
    Grid.group!
    
    Log.info "Generating body HTML..."    
    
    # Passing around the reference for styles hash and font map
    # Other way would be to have a singleton function, would change if it gets
    # messier.
    body_html = grid.to_html({ 
      :styles_hash => styles_hash, 
      :font_map => font_map })
    
    wrapper   = File.new Rails.root.join('app', 'assets', 'wrapper_templates', 'bootstrap_wrapper.html'), 'r'
    html      = wrapper.read
    wrapper.close
    
    html.gsub! "{yield}", body_html
    html.gsub! "{webfonts}", font_map.webfont_code
    
    better_file_name = (File.basename file_name, ".psd.json").underscore.gsub(' ', '_')
    folder_path      = Rails.root.join("generated", better_file_name)
    
    styles_hash.write_css_file folder_path
    
    raw_file_name  = folder_path.join 'raw.html'
    html_file_name = folder_path.join 'index.html'
    
    Log.info "Saving HTML file - #{html_file_name}..."
    html_fptr = File.new raw_file_name, 'w+'
    html_fptr.write html
    html_fptr.close
    
    Log.info "Tidying up the html..."
    system("tidy -q -o #{html_file_name} -f /dev/null -i #{raw_file_name}")
    
    Log.info "Successfully completed processing #{better_file_name}."
    font_map.show_install_urls
     
    return
  end
end
