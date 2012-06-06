require 'find'

class Design
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated
  include Mongoid::Versioning

  belongs_to :user
  has_many :grids
  
  # Design status types
  Design::STATUS_QUEUED     = :queued
  Design::STATUS_PROCESSING = :processing
  Design::STATUS_PROCESSED  = :processed

  field :name, :type => String
  field :psd_file_path, :type => String
  field :processed_file_path, :type => String
  
  field :font_map, :type => Hash, :default => {}
  field :typekit_snippet, :type => String, :default => ""
  field :google_webfonts_snippet, :type => String, :default => ""
  field :status, :type => String, :default => Design::STATUS_QUEUED

  mount_uploader :file, DesignUploader
  
  def safe_name_prefix
    self.name.gsub(/[^0-9a-zA-Z]/,'_')
  end
  
  def safe_name
    "#{self.safe_name_prefix}-#{self.id}"
  end

  def store_key_prefix
    File.join self.user.email, self.safe_name
  end
    
  def assets_root_path
    File.join self.store_key_prefix, 'generated'
  end
  
  def attribute_data
    grids = self.grids.collect do |grid|
      grid.attribute_data
    end
    
    layers = {}
    self.grids.each do |grid|
      grid.layer_ids.each do |layer_id|
        layer = Layer.find layer_id
        layers[layer.uid] = layer.attribute_data
      end        
    end
    
    {
      :name          => self.name,
      :psd_file_path => self.psd_file_path,
      :font_map      => self.font_map,
      :grids         => grids,
      :layers        => layers.values,
      :id            => self.safe_name
    }
  end
  
  def push_to_queue
    self.status = Design::STATUS_PROCESSING
    self.save!
  
    TaskQueue.push self.id.to_s
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
    
    # Set the root path for this design. That is where all the html and css is saved to.
    CssParser::set_assets_root self.assets_root_path
    
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
    raw_file_name  = File.join self.assets_root_path, 'raw.html'
    html_file_name = File.join self.assets_root_path, 'index.html'

    Log.info "Saving resultant HTML file #{html_file_name}"    
    Store.write html_file_name, html_content

    # Programatically do this so that it works on heroku
    #Log.info "Tidying up the html..."
    #system("tidy -q -o #{html_file_name} -f /dev/null -i #{raw_file_name}")
  end
  
  def write_css_files(css_content)
    Log.info "Writing css file..."    

    # Write style.css file
    css_path = File.join self.assets_root_path, "assets", "css"
    css_file_name = File.join css_path, "style.css"
    Store.write css_file_name, css_content

    # Copy bootstrap to assets folder
    Log.info "Writing bootstrap files"
    bootstrap_base_directory = Rails.root.join "app", "templates", "bootstrap", "docs"
    bootstrap_templates_directory = bootstrap_base_directory.join "assets"
    Find.find(bootstrap_templates_directory) do |file_name|
      # don't do anything if its a directory, just skip
      next if File.directory? file_name
      
      file_path     = Pathname.new file_name
      relative_path = file_path.relative_path_from(bootstrap_base_directory).to_s
      destination_path = File.join self.assets_root_path, relative_path
      Store::copy_from_local file_path, destination_path
    end
    
    bootrap_override_css = Rails.root.join("app", "assets", "stylesheets", "lib", "bootstrap_override.css").to_s
    target_css           = File.join self.assets_root_path, "assets", "css", "bootstrap_override.css"
    Store.copy_from_local bootrap_override_css, target_css
  end
end