class Utils
  def self.process_test_file
    self.process_file "/tmp/mailgun.psd.json"
  end
  
  def self.process_file(file_name)
    Log.info "Beginning to process #{file_name}..."
    fptr = File.new file_name
    json_data = fptr.read
    html = Analyzer.analyze json_data
    
    better_file_name = (File.basename file_name, ".psd.json").underscore.gsub(' ','_')
    folder_path      = Rails.root.join("generated", better_file_name)
    css_path         = folder_path.join("assets","css")
    css_file         = css_path.join "style.css"
    css_data         = PhotoshopItem::StylesHash.generate_css_file
    File.open(css_file, 'w') {|f| f.write(css_data) }
    
    Log.info "Creating css_path #{folder_path}"
    FileUtils.mkdir_p css_path
    
    html_file_name = folder_path.join 'index.html'
    html_fptr      = File.new html_file_name, 'w+'
    html_fptr.write html
    html_fptr.close
    
    Log.info "Successfully completed processing #{better_file_name}."
    
    return
  end
end