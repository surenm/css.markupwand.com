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
    
    #Set page level properties
    pageglobals = PageGlobals.instance
    pageglobals.page_bounds = BoundingBox.new(0,0,psd_data[:properties][:height], psd_data[:properties][:width])


    # Initialize styles hash and font map
    PhotoshopItem::FontMap.init art_layers
    
    # Layer descriptors of all photoshop layers
    Log.info "Getting nodes..."
    nodes = []
    art_layers.each do |layer_id, node_json|
      node = Layer.new
      node.set node_json
      nodes.push node
    end
    
    Grid.reset_grouping_queue
    
    Log.info "Creating grids..."
    grid = Grid.new 
    grid.set nodes, nil
    
    Grid.group!
    
    Log.info "Generating body HTML..."    
    
    # Passing around the reference for styles hash and font map
    # Other way would be to have a singleton function, would change if it gets
    # messier.
    better_file_name = (File.basename file_name, ".psd.json").underscore.gsub(' ', '_')
    folder_path      = Rails.root.join("..", "generated", better_file_name)
        
    CssParser::set_assets_root folder_path

    body_html = grid.to_html
    
    wrapper   = File.new Rails.root.join('app', 'assets', 'wrapper_templates', 'bootstrap_wrapper.html'), 'r'
    html      = wrapper.read
    wrapper.close
    
    html.gsub! "{yield}", body_html
    html.gsub! "{webfonts}", PhotoshopItem::FontMap.instance.webfont_code
    
    # Write style.css file
    PhotoshopItem::StylesHash.write_css_file
    
    # Copy bootstrap to assets folder
    Log.info "Writing bootstrap files"
    FileUtils.cp_r Rails.root.join("app", "assets", "bootstrap", "docs", "assets", "css"), folder_path.join("assets")
    FileUtils.cp Rails.root.join("app", "assets", "stylesheets", "bootstrap_override.css"), folder_path.join("assets", "css")
    
    raw_file_name  = folder_path.join 'raw.html'
    html_file_name = folder_path.join 'index.html'
    
    Log.info "Saving HTML file - #{html_file_name}..."
    html_fptr = File.new raw_file_name, 'w+'
    html_fptr.write html
    html_fptr.close
    
    Log.info "Tidying up the html..."
    system("tidy -q -o #{html_file_name} -f /dev/null -i #{raw_file_name}")
    
    Log.info "Successfully completed processing #{better_file_name}."
    PhotoshopItem::FontMap.instance.show_install_urls
     
    return
  end
end
