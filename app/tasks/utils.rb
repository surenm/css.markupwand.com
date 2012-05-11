class Utils
  def self.process_test_file
    self.process_file "/tmp/mailgun.psd.json"
  end
  
  def self.process_file(file_name, max_depth = 100)
    Log.info "Beginning to process #{file_name}..."

    fptr     = File.read file_name
    psd_data = JSON.parse fptr, :symbolize_names => true
    
    # A hash of all layers
    art_layers = psd_data[:art_layers]
    layer_sets = psd_data[:layer_sets]  

    # Layer descriptors of all photoshop layers
    all_layers_json = Hash.new
    all_layers_json.update art_layers
    all_layers_json.update layer_sets
    
    nodes = []
    art_layers.each do |layer_id, node_json|
      node         = PhotoshopItem::Layer.new(node_json)
      nodes.push node
    end

    Log.info "Getting nodes"
    
    nodes.each do |node|
      Log.debug "#{node} - #{node.bounds}"
    end

    Log.info "Done getting bounds, creating grids..."
    
    grid = Grid.new nodes, nil
    grid.group
    grid.print
    
    body_html = grid.to_html
    
    Log.info "Done generating body html"
    
    wrapper   = File.new Rails.root.join('app', 'assets', 'wrapper_templates', 'bootstrap_wrapper.html'), 'r'
    html      = wrapper.read
    wrapper.close
    
    html.gsub! "{yield}", body_html
    
    better_file_name = (File.basename file_name, ".psd.json").underscore.gsub(' ', '_')
    folder_path      = Rails.root.join("generated", better_file_name)
    css_path         = folder_path.join("assets", "css")
    
    Log.info "Creating css_path #{folder_path}"
    FileUtils.mkdir_p css_path
    
    css_file = css_path.join "style.css"
    css_data = PhotoshopItem::StylesHash.generate_css_file

    File.open(css_file, 'w') {|f| f.write(css_data) }
    
    raw_file_name = folder_path.join 'raw.html'
    html_file_name = folder_path.join 'index.html'
    html_fptr      = File.new raw_file_name, 'w+'
    html_fptr.write html
    html_fptr.close
    
    system("tidy -q -o #{html_file_name} -i #{raw_file_name}")
    
    Log.info "Successfully completed processing #{better_file_name}."
    Log.info "Generated HTML - #{html_file_name}, opening it."
    system("open '#{html_file_name}'")
    
    return
  end
end