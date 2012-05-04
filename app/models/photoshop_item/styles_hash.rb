class PhotoshopItem::StylesHash
  def initialize
    @styles = Hash.new
    @index  = 0
  end
  
  @@instance = PhotoshopItem::StylesHash.new
  
  def self.instance
    return @@instance
  end
  
  def add_and_get_class(css)
    
    if @styles.has_key? css
      Log.info "Repeating class #{@styles[css]}"
      return @styles[css]
    else
      @index = @index + 1
      class_name = 'class' + (@index).to_s
      Log.info "Creating class #{class_name}"
      @styles[css] = class_name
      return class_name
    end
  end
  
  def self.add_and_get_class(string)
    PhotoshopItem::StylesHash.instance.add_and_get_class(string)
  end
  
end