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
    end
    
    pp webfonts
    
  end
  
  def self.find_in_typekit(fonts_list)
    typekit_folder = Rails.root.join('db','json','typekit_fonts')
    files = Dir.new(typekit_folder).entries
    files.slice! 0, 2 # Remove '.' and '..'
    font_matches = {}
    
    # Create empty hash
    fonts_list.each { |font| font_matches[font] = [] }
    
    
    files.each do |file|
      file_path = typekit_folder.join(file)
      font_data = JSON.parse(File.open(file_path).read)
      library_type = font_data['library']['name']
      
      fonts_list.each do |font_name|
        matches = font_data['library']['families'].find_all do |typekit_font|
          typekit_font['name'] =~ /#{font_name}/i
        end 
        
        matches.each_with_index do |item,index|
          matches[index]['library_type'] = library_type
          matches[index]['source'] = 'typekit'
        end
        
        font_matches[font_name] += matches
      end
    end
    
    font_matches
  end
  
  def self.find_in_google_webfonts(fonts_list)
    google_folder =  Rails.root.join('db','json','google_webfonts')
    files = Dir.new(google_folder).entries
    files.slice! 0, 2 # Remove '.' and '..'
    
    font_matches = {}
    # Create empty hash
    fonts_list.each { |font| font_matches[font] = [] }
    
    files.each do |file|
      file_path = google_folder.join(file)
      font_data = JSON.parse(File.open(file_path).read)
      
      fonts_list.each do |font_name|
        matches = font_data['items'].find_all do |google_font|
          google_font['family'] =~ /#{font_name}/i
        end
        
        matches.each_with_index do |item,index|
          matches[index]['name'] = matches[index]['name']
          matches[index]['source'] = 'google'
        end
        
        font_matches[font_name] += matches
      end
    end
    
    font_matches
    
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