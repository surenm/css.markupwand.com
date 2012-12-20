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
  Design::STATUS_EXTRACTING   = :extracting
  Design::STATUS_GROUPING     = :grouping
  Design::STATUS_GRIDS        = :grids
  Design::STATUS_MARKUP       = :markup
  Design::STATUS_COMPLETED    = :completed
  Design::STATUS_FAILED       = :failed

  Design::STATUS_CLASS = {
    Design::STATUS_QUEUED       => 'label',
    Design::STATUS_UPLOADING    => 'label',
    Design::STATUS_UPLOADED     => 'label',
    Design::STATUS_PROCESSING   => 'label label-info',
    Design::STATUS_EXTRACTING   => 'label label-info',
    Design::STATUS_GROUPING     => 'label label-info',
    Design::STATUS_GRIDS        => 'label label-info',
    Design::STATUS_MARKUP       => 'label label-info',
    Design::STATUS_COMPLETED    => 'label label-success',
    Design::STATUS_FAILED       => 'label label-important'
  }
    
  
  Design::ERROR_FILE_ABSENT        = "file_absent"
  Design::ERROR_NOT_PHOTOSHOP_FILE = "not_photoshop_file"
  Design::ERROR_SCREENSHOT_FAILED  = "screenshot_failed"
  Design::ERROR_EXTRACTION_FAILED  = "extraction_failed"

  # File meta data
  field :name, :type => String
  field :psd_file_path, :type => String
  field :sif_file_path, :type => String, :default => nil
  field :status, :type => Symbol, :default => Design::STATUS_QUEUED
  field :softdelete, :type => Boolean, :default => false
  field :width, :type => Integer
  field :height, :type => Integer
  
  field :storage, :type => String, :default => "local"

  # Rating is Yes or No
  field :rating, :type => Boolean
  
  # CSS Related
  attr_accessor :class_edited
  
  # Document properties
  attr_accessor :resolution

  # Offset box buffer
  attr_accessor :row_offset_box

  # CSS class counter
  attr_accessor :css_counter

  # SIF accessor
  attr_accessor :sif

  mount_uploader :file, DesignUploader
  
  ##########################################################
  # Design Object helper functions
  ##########################################################
  def attribute_data(minimal=false)
    return {
      :name => self.name,
      :psd_file_path => self.psd_file_path,
      :id => self.safe_name,
      :status => self.status,
      :safe_name => self.safe_name,
      :safe_name_prefix => self.safe_name_prefix,
      :height => self.height,
      :width => self.width
    }
  end
  
  def get_serialized_sif_data
    self.init_sif
    sif_serialized_data = @sif.get_serialized_data

    # Get grouping boxes in an array as well
    grouping_boxes = Array.new
    self.root_grouping_box.each do |grouping_box|
      grouping_box_data = grouping_box.attribute_data
      grouping_box_data[:children] = nil
      grouping_boxes.push grouping_box_data
    end
    sif_serialized_data[:grouping_boxes] = grouping_boxes
    return sif_serialized_data
  end
  
  def get_grid_tree    
    root_node = self.get_root_grid
    dom = root_node.get_tree
    return dom
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
  end

  # FIXME PSDJS
  def webfonts_snippet
    return ''
    self.font_map.google_webfonts_snippet
  end
  
  def parse_fonts
    self.font_map = FontMap.new
    self.font_map.find_web_fonts self.layers
    self.font_map.save!
    self.save!
  end

  def get_fonts_styles_hash
    fonts = Hash.new
    index = 1
    self.layers.each do |uid, layer|
      if layer.type == Layer::LAYER_TEXT
        layer.text_chunks.each do |chunk|
          key = chunk[:styles]
          if not fonts.has_key? key
            fonts[key] = "font-#{index}"
            index += 1
          end
        end
      end
    end

    return fonts
  end

  def get_fonts_styles_scss
    fonts = self.get_fonts_styles_hash
    
    fonts_css = ""
    fonts.each do |font_styles, font_class_name|
      font_properties = ""
      font_styles.each do |key, value|
        if key == :'font-family'
          font_properties += "  #{key}: '#{value}';\n"
        else
          font_properties += "  #{key}: #{value};\n"
        end
      end
      fonts_css += ".#{font_class_name} { \n#{font_properties} }\n"
    end

    return fonts_css
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

  def get_css_counter
    if self.css_counter.nil?
      self.css_counter = 0
    else
      self.css_counter += 1
    end
    return self.css_counter
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

  ##########################################################
  # SIF related functions
  ##########################################################

  def init_sif(forced = false)
    @sif = Sif.new(self) if @sif == nil or forced
    self.height = @sif.header[:design_metadata][:height]
    self.width  = @sif.header[:design_metadata][:width]
    @sif
  end
  
  def grids
    self.init_sif
    @sif.grids
  end
  
  def layers
    self.init_sif
    @sif.layers
  end

  def root_grouping_box
    self.init_sif
    @sif.root_grouping_box
  end

  def root_grid
    self.init_sif
    @sif.root_grid
  end
  
  def save_grid(grid)
    self.init_sif
    @sif.set_grid grid
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

  def regroup
    self.init_sif
    @sif.reset_calculated_data

    generated_folder = self.store_generated_key
    published_folder = self.store_published_key
    tmp_folder = Rails.root.join 'tmp', 'store', self.store_key_prefix
    FileUtils.rm_rf tmp_folder
    Store.delete_from_store generated_folder
    Store.delete_from_store published_folder

    Resque.enqueue GroupingBoxJob, self.id
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
    self.save!
    
    message = self.get_processing_queue_message
    Resque.enqueue ProcessorJob, message
  end

  def push_to_extraction_queue
    Resque.enqueue ExtractorJob, self.id
  end
  ##########################################################
  # Actual jobs to be run on designs
  ########################################################## 
  def create_grouping_boxes
    self.init_sif

    Log.info "Beginning to create grouping boxes for #{self.name}..."    
    
    # Layer descriptors of all photoshop layers
    Log.info "Getting layers..."
    layers = self.layers.values
    
    Log.info "Creating root grouping box..."
    root_grouping_box = GroupingBox.new :layers => layers, :bounds => self.bounds, :design => self
    root_grouping_box.groupify

    @sif.root_grouping_box = root_grouping_box
    @sif.reset_grids
    @sif.save!

    Log.info "Successfully created all grouping_boxes."
  end

  
  def get_intersecting_pairs
    intersecting_pairs = []

    self.layers.each do |left_uid, node_left|
      self.layers.each do |right_uid, node_right|
        if left_uid != right_uid
          if node_left.bounds.intersect? node_right.bounds and !(node_left.bounds.encloses? node_right.bounds or node_right.bounds.encloses? node_left.bounds)
            if node_left.zindex < node_right.zindex
              intersecting_pairs.push [node_left, node_right]
            else
              intersecting_pairs.push [node_right, node_left]
            end
          end
        end
      end
    end

    intersecting_pairs.uniq
  end

  def create_grids
    self.init_sif(true)

    Log.info "Beginning to create grids for #{self.name}"
    root_grid = self.root_grouping_box.create_grid
    
    root_grid.each do |grid|
      grid.compute_styles
    end

    @sif.root_grid = root_grid
    @sif.save!
  end
  
  def generate_markup(args={})
    Log.info "Beginning to generate markup and css for #{self.name}..."
    self.init_sif(true)
    self.write_html_and_css
    Log.info "Successfully completed generating #{self.name}"
    return
  end

  def group_layers(layer_ids)
    self.init_sif

    # Get all the needed layers
    grouped_layers = layer_ids.collect {|layer_id| self.layers[layer_id.to_i]}
    
    # Get all the parent grouping boxes for those parents
    grouping_boxes = grouped_layers.collect do |layer|
      grouping_box_name = layer.grouping_box.to_s
      GroupingBox.get_node self.root_grouping_box, grouping_box_name
    end

    common_ancestor = GroupingBox.get_common_ancestor grouping_boxes
    return
  end

  # This usually called after changing CSS class names
  def write_html_and_css
    Log.info "Writing HTML and CSS..."

    # Set the base folder for writing html to
    generated_folder = self.store_generated_key
    published_folder = self.store_published_key

    # Set the root path for this design. That is where all the html and css is saved to.
    body_html    = self.root_grid.to_html
    compass_includes = <<COMPASS
@import "compass";
@import "compass/css3";
@import "compass/css3/box-shadow";
@import "compass/css3/border-radius";


COMPASS

    self.parse_fonts
    scss_content = self.font_map.font_scss + compass_includes  + self.get_fonts_styles_scss + self.root_grid.to_scss

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
