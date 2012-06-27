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
  Design::STATUS_QUEUED       = :queued
  Design::STATUS_UPLOADING    = :uploading
  Design::STATUS_UPLOADED     = :uploaded
  Design::STATUS_PROCESSING   = :processing
  Design::STATUS_PARSING      = :parsing
  Design::STATUS_PARSED       = :parsed
  Design::STATUS_GENERATING   = :generating
  Design::STATUS_REGENERATING = :regenerating
  Design::STATUS_COMPLETED    = :completed
  
  Design::STATUS_CLASS = {
    Design::STATUS_QUEUED       => 'label labe-inverse',
    Design::STATUS_UPLOADING    => 'label',
    Design::STATUS_UPLOADED     => 'label',
    Design::STATUS_PROCESSING   => 'label label-important',
    Design::STATUS_PARSING      => 'label label-warning',
    Design::STATUS_PARSED       => 'label label-warning',
    Design::STATUS_GENERATING   => 'label label-info',
    Design::STATUS_REGENERATING => 'label label-info',
    Design::STATUS_COMPLETED    => 'label label-success'
  }

  field :name, :type => String
  field :psd_file_path, :type => String
  field :processed_file_path, :type => String, :default => nil
  
  field :font_map, :type => Hash, :default => {}
  field :typekit_snippet, :type => String, :default => ""
  field :google_webfonts_snippet, :type => String, :default => ""
  field :status, :type => Symbol, :default => Design::STATUS_QUEUED
  field :storage, :type => String, :default => "local"
  
  field :height, :type => Integer
  field :width, :type => Integer
  field :resolution, :type => Integer

  mount_uploader :file, DesignUploader
  
  def safe_name_prefix
    Store::get_safe_name self.name
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
  
  def store_published_key
    File.join self.store_key_prefix, "published"
  end
  
  def get_root_grid
    root_grids = self.grids.where(:root => true)
    #Log.error "Root grid = #{root_grids.last.id.to_s}, #{root_grids.length}"
    Log.fatal "More than one root node in design???" if root_grids.size > 1

    return root_grids.last
  end
  
  def attribute_data
    grids       = {}
    layers      = {}
    css_classes = {}
    grid_data   = {}

    if self.status == Design::STATUS_COMPLETED
      grids = self.grids.collect do |grid|
        grid.attribute_data
      end
      
      self.grids.each do |grid|
        grid.layer_ids.each do |layer_id|
          layer = Layer.find layer_id
          layers[layer.uid] = layer.attribute_data
        end        
      end
      
      self.grids.each do |grid|
        grid_css_classes = grid.get_css_classes
        grid_css_classes.each do |css_class|
          css_classes[css_class] = Array.new if css_classes[css_class].nil?
          css_classes[css_class].push grid.id
        end
      end
      
      root_grid = self.get_root_grid
      dom_tree  = root_grid.get_tree
    end
    
    {
      :name          => self.name,
      :psd_file_path => self.psd_file_path,
      :font_map      => self.font_map,
      :grids         => grids,
      :layers        => layers.values,
      :id            => self.safe_name,
      :status        => self.status,
      :css_classes   => css_classes,
      :dom_tree      => dom_tree
    }
  end
  
  def set_status(status)
    self.status = status
    self.save!
  end

  # Offset box is a box, that is an empty grid that appears before
  # this current grid. The previous sibling being a empty box, it adds itself
  # to a buffer. And the next item picks it up from buffer and takes it as its 
  # own offset bounding box.
  #
  # This function is for serializing bounding box and storing it.
  def offset_box_buffer=(bounding_box)
    if bounding_box.nil?
      Rails.cache.delete "#{self.id}-offset_box" 
    else
      Rails.cache.write "#{self.id}-offset_box", BoundingBox.pickle(bounding_box)
    end
  end
  
  # Accessor for offset bounding box
  # De-serializes the offset box from mongo data.
  def offset_box_buffer
    offset_box_string = Rails.cache.read "#{self.id}-offset_box"
    if offset_box_string.nil?
      return nil
    else
      return BoundingBox.depickle offset_box_string
    end
  end
  
  def push_to_processing_queue
    self.set_status Design::STATUS_PROCESSING
    
    message = Hash.new

    if Constants::store_remote?
      message[:location] = "remote"
      message[:bucket] = Store::get_S3_bucket_name
    else 
      message[:location] = "local"
      message[:bucket]   = "store"
    end
    
    message[:user]   = self.user.email
    message[:design] = self.safe_name
    
    Resque.enqueue ProcessorJob, message
  end
  
  def parse_fonts(layers)
    design_fonts = FontMap.new layers
    
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

    self.height = psd_data[:properties][:height]
    self.width  = psd_data[:properties][:width]
    self.resolution = psd_data[:properties][:resolution]
    
    self.save!
    
    # Reset the global static classes to work for this PSD's data
    Grid.reset_grouping_queue
    
    # Layer descriptors of all photoshop layers
    Log.info "Getting nodes..."
    layers = []
    psd_data[:art_layers].each do |layer_id, node_json|
      layer = Layer.create_from_raw_data node_json, self.id
      layer.save!
      layers.push layer
      Log.debug "Added Layer #{layer} (#{layer.zindex})"
    end
    
    Log.info "Layer bounds"
    layers.each do |layer|
      Log.info "#{layer.bounds}"
    end

    Log.info "Creating root grid..."
    grid = Grid.new :design => self, :root => true, :depth => 0
    grid.set layers, nil
    grid.extract_body_style_layers
    grid.save!

    Log.info "Grouping the grids..."
    Grid.group!
    Log.info "Done grouping grids, printing now."
    grid.print
    Log.info "Done printing #{grid.id.to_s}"
  end
  
  def generate_markup(args={})
    # This populates the StylesHash css_classes simultaneously even though it returns only the html
    # TODO: make the interface better?
    Log.info "Generating body HTML..."
    
    # Set the base folder for writing html to
    generated_folder = self.store_generated_key
    published_folder = self.store_published_key
    
    self.parse_fonts(self.layers)

    # Set the root path for this design. That is where all the html and css is saved to.
    CssParser::set_assets_root generated_folder
    
    root_grid = self.get_root_grid

    body_html = root_grid.to_html
    wrapper = File.new Rails.root.join('app', 'assets', 'wrapper_templates', 'bootstrap_wrapper.html'), 'r'
    html    = wrapper.read
    wrapper.close

    body_class = StylesHash.generate_body_style(root_grid)

    html.gsub! "{yield}", body_html
    html.gsub! "{webfonts}", self.webfonts_snippet
    html.gsub! "{body_class}", body_class.to_s

    publish_html = Utils::strip_unwanted_attrs_from_html html

    css = StylesHash.generate_css_data

    self.write_html_files html, generated_folder
    self.write_css_files css, generated_folder
    
    Store.copy_within_store_recursively generated_folder, published_folder
    self.write_html_files publish_html, published_folder
  
    Log.info "Successfully completed processing #{self.processed_file_path}."
    return
  end
  
  def write_html_files(html_content, base_folder)
    html_file_name = File.join base_folder, 'index.html'

    # Programatically do this so that it works on heroku
    Log.info "Tidying up the html..."
    nasty_html = TidyFFI::Tidy.with_options(:indent => "auto",
      :indent_attributes => false, :char_encoding => 'utf8',
      :indent_spaces => 4, :wrap => 200).new(html_content)
    clean_html = nasty_html.clean
    
    Log.info "Saving resultant HTML file #{html_file_name}"    
    Store.write_contents_to_store html_file_name, clean_html
  end
  
  def write_css_files(css_content, base_folder)
    Log.info "Writing css file..."    

    # Write style.css file
    css_path = File.join base_folder, "assets", "css"
    css_file_name = File.join css_path, "style.css"
    Store.write_contents_to_store css_file_name, css_content

    # Copy bootstrap to assets folder
    Log.info "Writing bootstrap files..."
    
    bootrap_css = Rails.root.join("app", "templates", "bootstrap.css").to_s
    target_css  = File.join base_folder, "assets", "css", "bootstrap.css"
    Store.save_to_store bootrap_css, target_css
    
    override_css = Rails.root.join("app", "templates", "bootstrap_override.css").to_s
    target_css   = File.join base_folder, "assets", "css", "bootstrap_override.css"

    Store.save_to_store override_css, target_css
  end
end