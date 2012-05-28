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
  
  def safe_name_prefix
    self.name.gsub(/[^0-9a-zA-Z]/,'_')
  end
  
  def assets_root_path
    # TODO: Point this to the right place
    Rails.root.join "..", "generated", "#{self.safe_name_prefix}-#{self.id}"
  end

  # Start initializing all the singletons classes
  def reset_globals(psd_data)
    #Set page level properties
    page_globals = PageGlobals.instance
    page_globals.page_bounds = BoundingBox.new 0, 0, psd_data[:properties][:height], psd_data[:properties][:width]

    # Initialize FontMap, a singleton
    # Contains all the fonts related info (typekit, google font etc etc) in the current document 
    PhotoshopItem::FontMap.init psd_data[:art_layers]
    
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

    art_layers = psd_data[:art_layers]
    layer_sets = psd_data[:layer_sets]
    
    # Reset the global static classes to work for this PSD's data
    reset_globals psd_data

    # Layer descriptors of all photoshop layers
    Log.info "Getting nodes..."
    nodes = []
    art_layers.each do |layer_id, node_json|
      layer = Layer.new
      layer.set node_json
      nodes.push layer
      Log.debug "Added Layer #{layer.name}."
    end

    Log.info "Creating grids..."
    grid = Grid.new :design => self
    grid.set nodes, nil

    Log.info "Grouping the grids..."
    Grid.group!
    grid.print
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
    html.gsub! "{webfonts}", PhotoshopItem::FontMap.instance.webfont_code
    
    css = PhotoshopItem::StylesHash.generate_css_data
    
    # Write style.css file
    PhotoshopItem::StylesHash.write_css_file

    # Copy bootstrap to assets folder
    Log.info "Writing bootstrap files"
    FileUtils.cp_r Rails.root.join("app", "templates", "bootstrap", "docs", "assets", "css"), self.assets_root_path.join("assets")
    FileUtils.cp Rails.root.join("app", "assets", "stylesheets", "lib", "bootstrap_override.css"), self.assets_root_path.join("assets", "css")

    raw_file_name  = self.assets_root_path.join 'raw.html'
    html_file_name = self.assets_root_path.join 'index.html'

    Log.info "Saving HTML file - #{html_file_name}..."
    html_fptr = File.new raw_file_name, 'w+'
    html_fptr.write html
    html_fptr.close

    Log.info "Tidying up the html..."
    system("tidy -q -o #{html_file_name} -f /dev/null -i #{raw_file_name}")

    Log.info "Successfully completed processing #{self.processed_file_path}."
    PhotoshopItem::FontMap.instance.show_install_urls

    return
  end
end
