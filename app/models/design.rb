class Design
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated
  include Mongoid::Versioning

  belongs_to :user
  has_many :grids

  field :name, :type => String
  field :psd_file_path, :type => String
  field :processed_file_path, :type => String
  
  field :font_map, :type => Hash, :default => {}
  field :typekit_snippet, :type => String, :default => ""
  field :google_webfonts_snippet, :type => String, :default => ""
  
  def safe_name_prefix
    self.name.gsub(/[^0-9a-zA-Z]/,'_')
  end
  
  def assets_root_path
    # TODO: Point this to the right place
    assets_path = Rails.root.join "..", "generated", "#{self.safe_name_prefix}-#{self.id}"
    if not Dir.exists? assets_path
      FileUtils.mkdir_p assets_path
    end
    
    return assets_path
  end

  def parse_fonts(layers)
    design_fonts = PhotoshopItem::FontMap.new layers
    
    self.font_map.update design_fonts.font_map
    self.typekit_snippet = design_fonts.typekit_snippet
    self.google_webfonts_snippet = design_fonts.google_webfonts_snippet
    self.save!
  end
  
  def webfonts_snippet
    # TODO Generate this depending upon user
    # The javascript url is user specific.
    typekit_header = <<HTML
    <script type="text/javascript" src="http://use.typekit.com/kdl3dlc.js"></script>
    <script type="text/javascript">try{Typekit.load();}catch(e){}</script>  
HTML
    
    "#{typekit_header}\n #{self.typekit_snippet} \n #{self.google_webfonts_snippet}"
  end

  # Start initializing all the singletons classes
  def reset_globals(psd_data)
    #Set page level properties
    page_globals = PageGlobals.instance
    page_globals.page_bounds = BoundingBox.new 0, 0, psd_data[:properties][:height], psd_data[:properties][:width]
    
    # Reset the grouping queue. Its the FIFO order in which the grids are processed
    Grid.reset_grouping_queue
    
    # Set the root path for this design. That is where all the html and css is saved to.
    CssParser::set_assets_root self.assets_root_path
  end
  
  # Parses the photoshop file json data and decomposes into grids
  def parse
    Log.info "Beginning to process #{self.processed_file_path}..."
    
    # Set the name of the design
    self.name = File.basename self.processed_file_path, '.psd.json'
    self.save!

    # Parse the JSON
    fptr     = File.read self.processed_file_path
    psd_data = JSON.parse fptr, :symbolize_names => true, :max_nesting => false

    # Reset the global static classes to work for this PSD's data
    reset_globals psd_data

    # Layer descriptors of all photoshop layers
    Log.info "Getting nodes..."
    layers = []
    psd_data[:art_layers].each do |layer_id, node_json|
      layer = Layer.create_from_raw_data node_json
      layers.push layer
      Log.debug "Added Layer #{layer.name}."
    end

    Log.info "Creating root grid..."
    grid = Grid.new :design => self, :root => true, :grid_depth => 0
    grid.set layers, nil

    Log.info "Grouping the grids..."
    Grid.group!
    Log.info "Done grouping grids"
  end
  
  def generate_markup
    # This populates the PhotoshopItem::StylesHash css_classes simultaneously even though it returns only the html
    # TODO: make the interface better?
    Log.info "Generating body HTML..."
    root_grid = self.grids.where(:root => true).first

    body_html = root_grid.to_html

    wrapper = File.new Rails.root.join('app', 'assets', 'wrapper_templates', 'bootstrap_wrapper.html'), 'r'
    html    = wrapper.read
    wrapper.close

    html.gsub! "{yield}", body_html
    html.gsub! "{webfonts}", self.webfonts_snippet

    css = PhotoshopItem::StylesHash.generate_css_data

    self.write_html_files(html)
    self.write_css_files(css)
  
    Log.info "Successfully completed processing #{self.processed_file_path}."
    return
  end
  
  def write_html_files(html_content)
    raw_file_name  = self.assets_root_path.join 'raw.html'
    html_file_name = self.assets_root_path.join 'index.html'

    Log.info "Saving resultant HTML file #{html_file_name}"
    
    html_fptr = File.new raw_file_name, 'w+'
    html_fptr.write html_content
    html_fptr.close

    Log.info "Tidying up the html..."
    system("tidy -q -o #{html_file_name} -f /dev/null -i #{raw_file_name}")
  end
  
  def write_css_files(css_content)
    # Write style.css file
    css_path = self.assets_root_path.join "assets", "css"

    if not Dir.exists? css_path
      FileUtils.mkdir_p css_path
    end

    Log.info "Writing css file..."    
    css_file_name = File.join css_path, "style.css"
    css_fptr = File.new css_file_name, 'w+'
    css_fptr.write css_content
    css_fptr.close

    # Copy bootstrap to assets folder
    Log.info "Writing bootstrap files"
    FileUtils.cp_r Rails.root.join("app", "templates", "bootstrap", "docs", "assets", "css"), self.assets_root_path.join("assets")
    FileUtils.cp Rails.root.join("app", "assets", "stylesheets", "lib", "bootstrap_override.css"), self.assets_root_path.join("assets", "css")
  end
end