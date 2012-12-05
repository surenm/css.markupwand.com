require 'find'

class Design
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated
  include Mongoid::Versioning
  include Mongoid::Document::Taggable
  include ActionView::Helpers::DateHelper

  belongs_to :user

  embeds_one :font_map
  
  # Design status types
  Design::STATUS_QUEUED       = :queued
  Design::STATUS_UPLOADING    = :uploading
  Design::STATUS_UPLOADED     = :uploaded
  Design::STATUS_PROCESSING   = :processing
  Design::STATUS_PROCESSED    = :processed
  Design::STATUS_EXTRACTING   = :extracting
  Design::STATUS_EXTRACTED    = :extracted
  Design::STATUS_CLIPPING     = :clipping
  Design::STATUS_CLIPPED      = :clipped
  Design::STATUS_PARSING      = :parsing
  Design::STATUS_PARSED       = :parsed
  Design::STATUS_GENERATING   = :generating
  Design::STATUS_REGENERATING = :regenerating
  Design::STATUS_COMPLETED    = :completed
  Design::STATUS_FAILED       = :failed

  Design::STATUS_CLASS = {
    Design::STATUS_QUEUED       => 'label label-info',
    Design::STATUS_UPLOADING    => 'label',
    Design::STATUS_UPLOADED     => 'label',
    Design::STATUS_PROCESSING   => 'label label-info',
    Design::STATUS_PROCESSED    => 'label label-info',
    Design::STATUS_EXTRACTING   => 'label label-info',
    Design::STATUS_EXTRACTED    => 'label label-info',
    Design::STATUS_PARSING      => 'label label-info',
    Design::STATUS_PARSED       => 'label label-info',
    Design::STATUS_GENERATING   => 'label label-info',
    Design::STATUS_REGENERATING => 'label label-info',
    Design::STATUS_COMPLETED    => 'label label-success',
    Design::STATUS_FAILED       => 'label label-important'
  }
  
  Design::ERROR_FILE_ABSENT        = "file_absent"
  Design::ERROR_NOT_PHOTOSHOP_FILE = "not_photoshop_file"
  Design::ERROR_SCREENSHOT_FAILED  = "screenshot_failed"
  Design::ERROR_EXTRACTION_FAILED  = "extraction_failed"

  Design::PRIORITY_NORMAL = :normal
  Design::PRIORITY_HIGH   = :high

  # File meta data
  field :name, :type => String
  field :psd_file_path, :type => String
  field :sif_file_path, :type => String, :default => nil
  field :status, :type => Symbol, :default => Design::STATUS_QUEUED
  field :softdelete, :type => Boolean, :default => false
  
  field :storage, :type => String, :default => "local"
  field :queue, :type => String, :default => Design::PRIORITY_NORMAL

  # Rating is Yes or No
  field :rating, :type => Boolean
  
  # CSS Related
  attr_accessor :class_edited
  
  # Document properties
  attr_accessor :height
  attr_accessor :width
  attr_accessor :resolution

  # Autoincrement counter
  attr_accessor :incremental_counter

  # Offset box buffer
  attr_accessor :row_offset_box

  # Sif
  attr_accessor :sif

  mount_uploader :file, DesignUploader
  
  ##########################################################
  # Design Object helper functions
  ##########################################################
  def attribute_data(minimal=false)
    return {
      :name          => self.name,
      :psd_file_path => self.psd_file_path,
      :id            => self.safe_name,
      :status        => self.status,
    }
  end
  
  def get_root_grid
    root_grids = []
    self.grids.each do |id, grid|
      root_grids.push grid if grid.root == true
    end

    Log.fatal "More than one root node in design???" if root_grids.size > 1

    return root_grids.last
  end
  
  def bounds 
    BoundingBox.new 0, 0, self.height, self.width
  end
    
  def set_status(status)
    Log.info "Setting status == #{status}"
    self.status = status
    self.save!

    if self.status == Design::STATUS_COMPLETED
      if not self.user.admin
        to      = "#{self.user.name} <#{self.user.email}>"
        subject = "#{self.name} generated"
        text    = "Your HTML & CSS has been generated, click http://#{ENV['APP_URL']}/design/#{self.safe_name}/preview to download"
        ApplicationHelper.post_simple_message to, subject, text
      end
    end
  end

  def incremental_counter
    if @incremental_counter.nil?
      @incremental_counter = 1
      return @incremental_counter
    end
    @incremental_counter = @incremental_counter + 1
    return @incremental_counter
  end
  
  def get_next_grid_id
    # Minimal version of mongodb's object id.
    # http://www.mongodb.org/display/DOCS/Object+IDs
    # For incremental object ids.
    process_id  = "%07d" % $$ #7 digits
    time_micro  = ("%0.6f" % Time.now.to_f).gsub(".", "") #16 digits
    incremental = "%04d" % self.incremental_counter #4 digits
    new_id = (time_micro + process_id + incremental).to_i.to_s(16)
    return new_id
  end

  def get_next_layer_uid
    self.layers.keys.sort.last + 1
  end
  
  # FIXME PSDJS
  def webfonts_snippet
    return ''
    self.font_map.google_webfonts_snippet
  end
  
  def parse_fonts(layers)
    self.font_map = FontMap.new
    self.font_map.find_web_fonts layers
    self.font_map.save!
    self.save!
  end
  
  def vote_class
    case self.rating
    when true
      return 'good'
    when false
      return 'bad'
    when nil
      return 'none'
    end
  end
  ##########################################################
  # Store related functions
  ##########################################################
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
  
  def store_extracted_key
    File.join self.store_key_prefix, "extracted"
  end
  
  def offset_box_key
    "#{self.id}-offset_box"
  end
  
  def row_offset_box_key
    "#{self.id}-row_offset_box"
  end
  
  def get_photoshop_file_path
    safe_basename = Store::get_safe_name File.basename(self.name, ".psd")
    File.join self.store_key_prefix, "#{safe_basename}.psd"
  end
  
  def get_sif_file_path
    safe_basename = Store::get_safe_name File.basename(self.name, ".psd")
    File.join self.store_key_prefix, "#{safe_basename}.sif"
  end

  def get_conversion_time
    if self.status == Design::STATUS_COMPLETED
      completed_time = self.updated_at.to_i
      queued         = self.versions.select { |version| version.status == :queued }  
      if not queued.empty?
        queued_time = queued.first.updated_at.to_i
        time_taken  = (completed_time - queued_time)
        time_taken_string = "%02d:%02d" % [(time_taken / 60), (time_taken % 60)]
        return distance_of_time_in_words(time_taken) + "(#{time_taken_string}m)"
      else
        return "invalid"
      end
    else
      return "invalid"
    end
  end

  def get_sif_data
    Store::fetch_data_from_store(self.get_sif_file_path)
  end

  def save_sif!
    @sif.save! if @sif != nil
  end

  ##########################################################
  # SIF related functions
  ##########################################################
  def init_sif
    @sif = Sif.new(self) if @sif == nil
    self.height = @sif.header[:design_metadata][:height]
    self.width  = @sif.header[:design_metadata][:width]
    return @sif
  end
  
  def grids
    self.init_sif
    return @sif.grids
  end
  
  def layers
    self.init_sif
    return @sif.layers
  end
  
  def save_grid(grid)
    self.init_sif
    @sif.set_grid grid
  end

  ##########################################################
  # Row grid and grid offset box related methods
  ##########################################################
  # Offset box is a box, that is an empty grid that appears before
  # this current grid. The previous sibling being a empty box, it adds itself
  # to a buffer. And the next item picks it up from buffer and takes it as its 
  # own offset bounding box.
  #
  
  @@grid_offset_box = nil
  @@row_offset_box  = nil
  
  # This function is for serializing bounding box and storing it.
  def add_offset_box(bounding_box)
    new_offset_box = nil
    if self.offset_box.nil?
      new_offset_box = bounding_box
    else 
      new_offset_box = BoundingBox.get_super_bounds [bounding_box, self.offset_box]
    end
     @@grid_offset_box = new_offset_box
  end
  
  # Accessor for offset bounding box
  # De-serializes the offset box from mongo data.
  def offset_box
    @@grid_offset_box
  end
  
  def reset_offset_box
    @@grid_offset_box = nil
  end
  
  def row_offset_box=(bounding_box)
    @@row_offset_box = bounding_box
  end
  
  def row_offset_box
    @@row_offset_box
  end
  
  def reset_row_offset_box
    @@row_offset_box = nil
  end
  
  ##########################################################
  # Helper methods for running jobs on designs
  ##########################################################
  def reextract
    # delete sif files and extracted folder and start again
    sif_file = self.get_sif_file_path
    extracted_folder = self.store_extracted_key
    tmp_folder = Rails.root.join 'tmp', 'store', self.store_key_prefix
    FileUtils.rm_rf tmp_folder
    Store.delete_from_store sif_file
    Store.delete_from_store extracted_folder
    self.set_status Design::STATUS_QUEUED
    
    self.push_to_extraction_queue
  end

  def reprocess
    sif_file = self.get_sif_file_path
    processed_folder = self.store_processed_key
    extracted_folder = self.store_extracted_key

    Store.delete_from_store sif_file
    Store.delete_from_store extracted_folder

    tmp_folder = Rails.root.join 'tmp', 'store', self.store_key_prefix
    FileUtils.rm_rf tmp_folder
    
    self.set_status Design::STATUS_QUEUED
    self.push_to_processing_queue
  end

  def reparse
    # if sif files exist, remove grids from it and reparse
    #self.init_sif  
    #@sif.reset_grids
    #self.set_status Design::STATUS_PARSING
    #Resque.enqueue ParserJob, self.id
    self.init_sif  
    @sif.reset_grids
    generated_folder = self.store_generated_key
    published_folder = self.store_published_key
    tmp_folder = Rails.root.join 'tmp', 'store', self.store_key_prefix
    FileUtils.rm_rf tmp_folder
    Store.delete_from_store generated_folder
    Store.delete_from_store published_folder
    self.set_status Design::STATUS_EXTRACTED
    
    self.push_to_parsing_queue
  end
  
  def regenerate
    # TODO: If generated/published folders exist delete and remove those files and regenerate
  end
  
  def get_processing_queue_message
    message = Hash.new
    if Constants::store_remote?
      message[:location] = "remote"
      message[:bucket] = Store::get_S3_bucket_name
    else 
      message[:location] = "local"
      message[:bucket]   = "store_local"
    end
    
    message[:user]   = self.user.email
    message[:design] = self.safe_name
    message[:design_id] = self.id.to_s


    return message
  end
  
  def push_to_processing_queue
    self.set_status Design::STATUS_PROCESSING
    self.queue = Design::PRIORITY_NORMAL
    self.save!
    
    message = self.get_processing_queue_message
    Resque.enqueue ProcessorJob, message
  end

  def move_to_priority_queue
    message = self.get_processing_queue_message
    Resque.dequeue ProcessorJob, message
    Resque.enqueue PriorityProcessorJob, message
    self.queue = Design::PRIORITY_HIGH
    self.save!
  end

  def push_to_extraction_queue
    Resque.enqueue ExtractorJob, self.id
  end

  def push_to_parsing_queue
    Resque.enqueue ParserJob, self.id
  end

  def push_to_generation_queue
    self.set_status Design::STATUS_GENERATING
    Resque.enqueue GeneratorJob, self.id
  end 
  
  ##########################################################
  # Actual jobs to be run on designs
  ########################################################## 
  
  # Parses the photoshop file json data and decomposes into grids
  def group_grids
    self.init_sif

    Log.info "Beginning to group grids #{self.name}..."    
    #TODO: Resolution information is hidden somewhere in the psd file. pick it up
    #self.resolution = psd_data[:properties][:resolution]
    
    # Reset the global static classes to work for this PSD's data
    Grid.reset_grouping_queue
    
    # Layer descriptors of all photoshop layers
    Log.info "Getting nodes..."
    @layers = @sif.layers.values
    
    Log.info "Creating root grid..."
    grid = Grid.new :design => self, :parent => nil, :layers => @layers, :root => true, :group => true

    Log.info "Grouping the grids..."
    Grid.group!
    grid.print
    @sif.save!
    Log.info "Successfully grouped grids..."
  end
  
  def generate_markup(args={})
    Log.info "Beginning to generate markup and css for #{self.name}..."
    
    self.init_sif
    generated_folder = self.store_generated_key
    
    # Set the root path for this design. That is where all the html and css is saved to.
    
    Log.info "Parsing fonts..."
    # TODO Fork out and parallel process
    self.parse_fonts(self.layers)

    root_grid = self.get_root_grid

    # Once grids are generated, run through the tree and find out style sheets.
    # TODO Fork out and parallel process
    Log.info "Generating CSS Tree..."
    root_grid.style.compute_css

    Log.debug "Destroying design globals..."
    DesignGlobals.destroy

    self.write_html_and_css
    
    @sif.save!
    Log.info "Successfully completed generating #{self.name}"
    return
  end

  # This usually called after changing CSS class names
  def write_html_and_css
    Log.info "Writing HTML and CSS..."

    # Set the base folder for writing html to
    generated_folder = self.store_generated_key
    published_folder = self.store_published_key

    # Set the root path for this design. That is where all the html and css is saved to.
    
    root_grid    = self.get_root_grid
    body_html    = root_grid.to_html
    compass_includes = <<COMPASS
@import "compass";
@import "compass/css3";
@import "compass/css3/box-shadow";
@import "compass/css3/border-radius";


COMPASS
    scss_content = self.font_map.font_scss + compass_includes + root_grid.style.to_scss

    wrapper = File.new Rails.root.join('app', 'assets', 'wrapper_templates', 'bootstrap_wrapper.html'), 'r'
    html    = wrapper.read
    wrapper.close

    html.gsub! "{yield}", body_html
    html.gsub! "{webfonts}", self.webfonts_snippet

    publish_html = Utils::strip_unwanted_attrs_from_html html
    self.write_html_files html, generated_folder
    self.write_css_files scss_content, generated_folder
    
    Store.copy_within_store_recursively generated_folder, published_folder
    self.write_html_files publish_html, published_folder
    self.write_css_files scss_content, published_folder
  end
  
  def write_html_files(html_content, base_folder)
    html_file_name = File.join base_folder, 'index.html'

    # Programatically do this so that it works on heroku
    Log.debug "Tidying up the html..."
    nasty_html = TidyFFI::Tidy.with_options(:indent => "auto",
      :indent_attributes => false, :char_encoding => 'utf8',
      :indent_spaces => 4, :wrap => 200).new(html_content)
    clean_html = nasty_html.clean
    
    Log.info "Saving resultant HTML file #{html_file_name}"    
    Store.write_contents_to_store html_file_name, clean_html
  end

  # Right now convert using the system command
  # Figure out how to do this via function call, later.
  def generate_css_from_sass(scss_content)
    compile_dir = Rails.root.join("tmp", self.safe_name)
    FileUtils.mkdir_p compile_dir
    config_rb = <<config
http_path = ""
css_dir = "."
sass_dir = "."
output_style = :expanded 
line_comments = false
preferred_syntax = :scss
relative_assets = true    
fonts_dir = ""   
config
    
    scss_file = Rails.root.join("tmp", self.safe_name, 'style.scss')
    File.open(scss_file, 'w+') { |f| f.write(scss_content) }

    config_rb_file = Rails.root.join("tmp", self.safe_name, 'config.rb')
    File.open(config_rb_file, 'w+') { |f| f.write(config_rb) }

    Log.info "Compile sass to css"
    system "cd #{compile_dir} && compass compile ."
    css_content = ''

    css_file     = Rails.root.join("tmp", self.safe_name, 'style.css')
    css_contents = ''

    if File.exists? css_file
      css_contents = File.open(css_file, 'r').read
    end

    css_contents
  end

  def write_css_files(scss_content, base_folder)
    Log.info "Writing css (compass) file..."    

    # Write style.scss file and style.css file
    scss_path = File.join base_folder, "assets", "css"
    scss_file_name = File.join scss_path, "style.scss"
    indented_scss = Utils::indent_scss scss_content
    Store.write_contents_to_store scss_file_name, indented_scss

    css_path = File.join base_folder, "assets", "css"
    css_file_name = File.join css_path, "style.css"
    Store.write_contents_to_store css_file_name, generate_css_from_sass(scss_content)

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
