require 'find'

class Design
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated
  include Mongoid::Versioning

  belongs_to :user
  has_many :grids
  has_many :layers
  
  # Design status types
  Design::STATUS_QUEUED     = :queued
  Design::STATUS_PROCESSING = :processing
  Design::STATUS_PROCESSED  = :processed
  Design::STATUS_GENERATING = :generating
  Design::STATUS_COMPLETED  = :completed

  field :name, :type => String
  field :psd_file_path, :type => String
  field :processed_file_path, :type => String, :default => nil
  
  field :font_map, :type => Hash, :default => {}
  field :typekit_snippet, :type => String, :default => ""
  field :google_webfonts_snippet, :type => String, :default => ""
  field :status, :type => String, :default => Design::STATUS_QUEUED
  field :storage, :type => String, :default => "local"

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
  
  def store_generated_key
    File.join self.store_key_prefix, "generated"
  end
  
  def store_processed_key
    File.join self.store_key_prefix, "processed"
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
  
  def set_status(status)
    self.status = status
    self.save!
  end
  
  def push_to_processing_queue(callback_url)
    self.status = Design::STATUS_PROCESSING
    self.save!
    
    message = Hash.new

    message[:callback_uri] = callback_url

    if Constants::store_remote?
      message[:location] = "remote"
      if Rails.env.production? 
        message[:bucket] = "store_production"
      else 
        message[:bucket] = "store_development"
      end
    else 
      message[:location] = "local"
      message[:bucket]   = "store"
    end
    
    message[:user]   = self.user.email
    message[:design] = self.safe_name
    
    # message will be something like "remote store_production callback_url bot@goyaka.com test_psd_#{design_mongo_id}"
    message = "#{message[:location]} #{message[:bucket]} #{message[:callback_uri]} #{message[:user]} #{message[:design]}"
    ProcessingQueue.push message
  end
  
  def push_to_generation_queue
    Resque.enqueue MarkupGeneratorJob, self.id
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
    if self.processed_file_path.nil? or self.processed_file_path.empty?
      Log.fatal "Processed file not specified"
      exit
    end
    
    Log.info "Beginning to process #{self.processed_file_path}..."

    # Parse the JSON
    fptr     = File.read self.processed_file_path
    psd_data = JSON.parse fptr, :symbolize_names => true, :max_nesting => false

    # Reset the global static classes to work for this PSD's data
    reset_globals psd_data

    # Layer descriptors of all photoshop layers
    Log.info "Getting nodes..."
    layers = []
    psd_data[:art_layers].each do |layer_id, node_json|
      layer = Layer.create_from_raw_data node_json, self
      layers.push layer
      Log.debug "Added Layer #{layer}."
    end
    
    Log.info "Layer bounds"
    layers.each do |layer|
      Log.info "#{layer.bounds}"
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
    CssParser::set_assets_root self.store_generated_key
    
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
    raw_file_name  = File.join self.store_generated_key, 'raw.html'
    html_file_name = File.join self.store_generated_key, 'index.html'

    Log.info "Saving resultant HTML file #{html_file_name}"    
    Store.write_contents_to_store html_file_name, html_content

    # Programatically do this so that it works on heroku
    #Log.info "Tidying up the html..."
    #system("tidy -q -o #{html_file_name} -f /dev/null -i #{raw_file_name}")
  end
  
  def write_css_files(css_content)
    Log.info "Writing css file..."    

    # Write style.css file
    css_path = File.join self.store_generated_key, "assets", "css"
    css_file_name = File.join css_path, "style.css"
    Store.write_contents_to_store css_file_name, css_content

    # Copy bootstrap to assets folder
    Log.info "Writing bootstrap files..."
    
    bootrap_css = Rails.root.join("app", "templates", "bootstrap.css").to_s
    target_css  = File.join self.store_generated_key, "assets", "css", "bootstrap_override.css"
    Store.save_to_store bootrap_css, target_css
    
    override_css = Rails.root.join("app", "templates", "bootstrap_override.css").to_s
    target_css   = File.join self.store_generated_key, "assets", "css", "bootstrap_override.css"

    Store.save_to_store bootrap_override_css, target_css
  end
end