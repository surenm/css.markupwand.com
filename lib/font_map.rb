class FontMap
  attr_accessor :layers, :font_map, :typekit_snippet, :google_webfonts_snippet

  FONT_MAP = { 'Helvetica World' => 'Helvetica' }

  # Base fonts for browsers
  # http://en.wikipedia.org/wiki/Core_fonts_for_the_Web
  DEFAULT_FONTS = ['Helvetica', 'Lucida Sans', 'Tahoma', 'Andale Mono',
     'Arial', 'Arial Black', 'Comic Sans MS', 'Courier New', 'Georgia',
     'Impact', 'Times New Roman', 'Trebuchet MS', 'Verdana', 'Webdings']
  
  def initialize(layers)
    @layers = layers
    self.find_web_fonts    
  end
  
  # Find out fonts and urls from
  # Google and Typekit
  def find_web_fonts    
    fonts_list = []

    @layers.each do |layer|
      raw_layer_font = layer.get_raw_font_name
      if not DEFAULT_FONTS.include? raw_layer_font
        fonts_list.push raw_layer_font
      end
    end

    fonts_list.uniq!
    fonts_list.compact!
        
    typekit_fonts = find_in_typekit(fonts_list)
    google_fonts  = find_in_google(fonts_list)
    
    @font_map = {}
    @font_map.update typekit_fonts[:map]
    @font_map.update google_fonts[:map]
    
    @google_webfonts_snippet = google_fonts[:snippet]
    @typekit_snippet = if not typekit_fonts[:snippet].empty? then typekit_fonts[:snippet]  else '' end
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
        matches = font_data['items'].find_all do |google_font|
          google_font['family'] =~ /#{reduced_font_name(font_name)}/i
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

  def reduced_font_name(font)
    removable_patterns = ['-Bold', '-Regular']
    modified_font = font
    removable_patterns.each do |pattern|
      modified_font = modified_font.gsub(pattern,'')
    end

    modified_font
  end
  
end