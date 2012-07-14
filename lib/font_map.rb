class FontMap
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated  

  embedded_in :design

  attr_accessor :layers

  field :font_map_hash, :type => Hash, :default => {}
  field :typekit_snippet, :type => Hash, :default => {}
  field :google_webfonts_snippet, :type => Hash, :default => {}
  field :missing_fonts, :type => Array, :default => []
  field :uploaded_fonts, :type => Hash, :default => {}

  FONT_MAP = { 'Helvetica World' => 'Helvetica' }

  # Base fonts for browsers
  # http://en.wikipedia.org/wiki/Core_fonts_for_the_Web
  DEFAULT_FONTS = ['Helvetica', 'Lucida Sans', 'Tahoma', 'Andale Mono',
     'Arial', 'Arial Black', 'Comic Sans MS', 'Courier New', 'Georgia',
     'Impact', 'Times New Roman', 'Trebuchet MS', 'Verdana', 'Webdings']

  
  # Find out fonts and urls from
  # Google and Typekit
  def find_web_fonts(layers)
    fonts_list = []

    layers.each do |layer|
      raw_layer_font = layer.get_raw_font_name
      if not DEFAULT_FONTS.include? raw_layer_font
        fonts_list.push raw_layer_font
      end
    end

    fonts_list.uniq!
    fonts_list.compact!
        
    google_fonts  = find_in_google(fonts_list)
    
    self.font_map_hash = {}
    self.font_map_hash.update google_fonts[:map]
    self.missing_fonts = fonts_list.clone
    self.font_map_hash.each do |font_name, _|
      self.missing_fonts.delete font_name
    end

    copy_from_userfonts(fonts_list)

    self.google_webfonts_snippet = google_fonts[:snippet]
    self.typekit_snippet = ''
    self.save!
  end

  def get_font(font_name)
    if self.font_map_hash.has_key? font_name
      self.font_map_hash[font_name]
    else
      font_name
    end
  end
  
  def find_in_typekit(fonts_list)
    typekit_folder = Rails.root.join('db','json','typekit_fonts')
    files = Dir["#{typekit_folder}/**"]
    font_matches = {}
    
    # Create empty hash
    fonts_list.each { |font| font_matches[font] = [] }
    
    # Make this better. Exact matches should have higher priority
    files.each do |file|
      file_path = typekit_folder.join(file)
      font_data = JSON.parse(File.open(file_path).read)
      
      fonts_list.each do |font_name|

        matches = font_data['library']['families'].find_all do |typekit_font|
          typekit_font['name'] =~ /#{reduced_font_name(font_name)}/i
        end 
                        
        font_matches[font_name] += matches
        
        # Unique them
        font_matches[font_name].uniq! { |font_item| font_item['id'] }
        
      end
    end
    
    font_map  = {}
    font_urls = []
    
    # Pick out the uniq items
    # Right now, pick the first item. Optimize this later.
    fonts_list.each do |font|
      begin
        if not font_matches[font].empty?
          font_data = font_matches[font].first
          font_json = ApplicationHelper::get_json("http://typekit.com#{font_data['link']}")
          font_map[font]  = font_json['family']['slug']
          font_urls.push font_json['family']['web_link']
        end
      rescue SocketError => error
      end
    end
    
    { :snippet => font_urls, :map => font_map }
  end
  
  # Gives out a font map to be used in css and 
  # URL to be inserted for getting those fonts.
  # 
  # Returns a hash, embed_url and font_map
  def find_in_google(fonts_list)
    google_folder =  Rails.root.join('db','json','google_webfonts')
    files = Dir["#{google_folder}/**"]
  
    font_name_array = []
    
    font_matches = {}
    # Create empty hash
    fonts_list.each { |font| font_matches[font] = nil }
    
    files.each do |file|
      file_path = google_folder.join(file)
      font_data = JSON.parse(File.open(file_path).read)
  
      fonts_list.each do |font_name|
        reduced_font = reduced_font_name(font_name, true)
        matches = font_data['items'].find_all do |google_font|
          google_font['family'] =~ /#{reduced_font}/i
        end
        
        if matches.length > 0
          font_matches[font_name] = matches.first
        end
    
      end
    end
    
    font_map = {}
    font_variants = {}
    font_matches.each do |font_name, font_data|
      if font_data
        font_map[font_name] = font_data['family']
        font_variants[font_name] = font_data['variants']
      end
    end
    
    font_map.each do |name, family|
      font_name = family.gsub(' ', '+')  + ':' + font_variants[name].join(',')
      font_name_array.push font_name
    end
    
    font_url_suffix = font_name_array.join '|'
    if font_name_array.length > 0
      webfont_code = <<HTML
<link href='http://fonts.googleapis.com/css?family=#{font_url_suffix}' rel='stylesheet' type='text/css'>
HTML
    else
      webfont_code = ''
    end

    {:snippet => webfont_code, :map => font_map }
  end

  def copy_from_userfonts(fonts_list)
    font_map = {}
    user_fonts = self.design.user.user_fonts
    user_fonts_obtained = []
    user_fonts.each do |font|
      if not fonts_list.find_index(font.fontname).nil?
        src  = font.file_path
        dest = self.design.store_published_key, "assets", "fonts", font.filename
        Store::copy_within_store src, dest
        user_fonts_obtained.push({ :name => font.fontname, :file => font.filename })
      end
    end

    user_fonts_obtained.each do |font|
      self.missing_fonts.delete font[:name]
      self.uploaded_fonts.update({ font[:name] => font[:file] })
      self.save!
    end

  end

  # Sample payload
  # {
  #  'Helvetica Neue'{
  #    url: "https://www.filepicker.io/api/file/XtsSASkBQyOJ8923bsWV",
  #    name: "HelveticaNeue.ttf",
  #    type: "ttf",
  #    generated: ".yy./generated/assets/fonts/Helvetica Neue.ttf",
  #    published: ".xx./published/assets/fonts/Helvetica Neue.ttf"
  #  },
  #  'MuseoSans': {
  #   ..sameasabove..
  #   }
  # }
  def update_downloaded_fonts(downloaded_fonts_data)
    downloaded_fonts_data.each do |font_name, font_data|
      stripped_font_name = font_name.gsub("'",'')
      self.missing_fonts.delete stripped_font_name
      uploaded_font = {stripped_font_name => font_data[:filename]}
      self.uploaded_fonts.update uploaded_font
    end
  end

  def reduced_font_name(font, google = true)
    removable_patterns = ['-Bold', '-Regular']
    modified_font = font
    removable_patterns.each do |pattern|
      modified_font = modified_font.gsub(pattern,'')
      if google
        # hack for google to convert camel cases to spaces
        modified_font_pieces = modified_font.split /(?=[A-Z])/
        modified_font_chomped = modified_font_pieces.map { |piece| piece.strip}
        modified_font = modified_font_chomped.join(" ")
      end
    end

    modified_font
  end

  # Writes out fonts scss
  # Uses compass/css3
  def font_scss
    if self.uploaded_fonts.length > 0 
      prelude = <<scss
@import "compass/css3";
scss
    
    uploaded_fonts_scss = ""
    self.uploaded_fonts.each do |font_name, font_filename|
      font_specific_scss = <<scss
@include font-face("#{font_name}", font-files("#{File.join "..", "fonts", font_filename}"));
scss
      uploaded_fonts_scss += font_specific_scss
    end

      return prelude + uploaded_fonts_scss
    else
      ""
    end
  end

  # Get filetype for a font file name
  def self.filetype(filename)
    filetype = filename.split('.').last
    filetype.downcase!

    case filetype
    when 'woff'
      return :woff
    when 'otf'
      return :otf
    else
      return :ttf
    end
  end

end