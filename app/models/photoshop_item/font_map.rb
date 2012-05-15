class PhotoshopItem::FontMap
  
  FONT_MAP = {
    'Helvetica World' => 'Helvetica'
  }
  
  attr_accessor :layers, :font_map, :typekit_install_urls
  
  def initialize(layers)
    @layers = layers
    @font_map = Hash.new
  end
  
  # Base fonts for browsers
  # http://en.wikipedia.org/wiki/Core_fonts_for_the_Web
  DEFAULT_FONTS = ['Helvetica', 'Lucida Sans', 'Tahoma', 'Andale Mono',
     'Arial', 'Arial Black', 'Comic Sans MS', 'Courier New', 'Georgia',
     'Impact', 'Times New Roman', 'Trebuchet MS', 'Verdana', 'Webdings']
  
  def self.find_web_fonts(layers)
    fonts_list = []
    layers.each do |layer_id, layer|
       fonts_list.push PhotoshopItem::FontMap.get_font_name(layer)
    end
    
    fonts_list.uniq!
    fonts_list.compact!
    fonts_list = fonts_list - DEFAULT_FONTS
    
    fonts_list
    
    typekit_fonts = PhotoshopItem::FontMap.find_in_typekit(fonts_list)
    google_fonts  =  PhotoshopItem::FontMap.find_in_google_webfonts(fonts_list)
    
    webfonts = {}
    fonts_list.each do |font|
      pp typekit_fonts[font]
      pp google_fonts[font]
      webfonts[font] = typekit_fonts[font] + google_fonts[font]
  def webfont_code
    # TODO Generate this depending upon user
    # The javascript url is user specific.
    typekit_code = <<HTML
    <script type="text/javascript" src="http://use.typekit.com/kdl3dlc.js"></script>
    <script type="text/javascript">try{Typekit.load();}catch(e){}</script>  
HTML
    webfont_code = ''
  
    if @typekit_install_urls.length > 0
      webfont_code += typekit_code
    end
    
    if not @google_webfont_code.empty?
      webfont_code += @google_webfont_code
    end
    
    webfont_code
  end
  
  def show_install_urls
    # Return the installable fonts to be clicked in UI
    
    if @typekit_install_urls.length > 0
      Log.info "Install these typekit fonts:" 
      @typekit_install_urls.each do |font_url|
        Log.info font_url
      end
    end
  end
  
  def find_in_typekit(fonts_list)
    typekit_folder = Rails.root.join('db','json','typekit_fonts')
    files = Dir.new(typekit_folder).entries
    files.slice! 0, 2 # Remove '.' and '..'
    font_matches = {}
    
    # Create empty hash
    fonts_list.each { |font| font_matches[font] = [] }
    
    # Make this better. Exact matches should have higher priority
    files.each do |file|
      file_path = typekit_folder.join(file)
      font_data = JSON.parse(File.open(file_path).read)
      
      fonts_list.each do |font_name|
        matches = font_data['library']['families'].find_all do |typekit_font|
          typekit_font['name'] =~ /#{font_name}/i
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
      if not font_matches[font].empty?
        font_data = font_matches[font].first
        font_json = ApplicationHelper::get_json("http://typekit.com#{font_data['link']}")
        font_map[font]  = font_json['family']['slug']
        font_urls.push font_json['family']['web_link']
      end
    end
    
    { :install_url => font_urls, :map => font_map }
  end
  
  # Gives out a font map to be used in css and 
  # URL to be inserted for getting those fonts.
  # 
  # Returns a hash, embed_url and font_map
  def find_in_google(fonts_list)
    google_folder =  Rails.root.join('db','json','google_webfonts')
    files = Dir.new(google_folder).entries
    files.slice! 0, 2 # Remove '.' and '..'
  
    font_name_array = []
    
    font_matches = {}
    # Create empty hash
    fonts_list.each { |font| font_matches[font] = nil }
    
    files.each do |file|
      file_path = google_folder.join(file)
      font_data = JSON.parse(File.open(file_path).read)
      
      fonts_list.each do |font_name|
        matches = font_data['items'].find_all do |google_font|
          google_font['family'] =~ /#{font_name}/i
        end
        
        if matches.length > 0
          font_matches[font_name] = matches.first
        end
    
      end
    end
    
    font_map = {}
    font_matches.each do |font_name, font_data|
      if font_data
        font_map[font_name] = font_data['family']
      end
    end
    
    font_map.each { |name, family| font_name_array.push family.gsub(' ', '+') }
    font_url_suffix = font_name_array.join '|'
    if font_name_array.length > 0
      webfont_code = <<HTML
<link href='http://fonts.googleapis.com/css?family=#{font_url_suffix}' rel='stylesheet' type='text/css'>
HTML
    else
      webfont_code = ''
    end

    {:webfont_code => webfont_code, :map => font_map }
  end
  
  def get_font_name(layer, raw = false)
    if layer[:layerKind] == PhotoshopItem::Layer::LAYER_TEXT
      text_style = layer[:textKey][:value][:textStyleRange][:value].first
      font_info  = text_style[:value][:textStyle][:value]
      font_name  = font_info[:fontName][:value]
      
      if not raw 
        if FONT_MAP.has_key? font_name
          FONT_MAP[font_name]
        elsif @font_map.has_key? font_name
          "'#{@font_map[font_name]}'"
        end
      else
        font_name
      end
    end
  end
end