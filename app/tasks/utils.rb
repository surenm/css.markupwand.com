class Utils
  def self.process_test_file
    self.process_file '/tmp/mailgun.psd.json', true
  end
  
  def self.process_file(file_name, profile = false)
    RubyProf.start if profile
    
    user = User.find_by_email 'bot@goyaka.com'
    design = Design.new :processed_file_path => file_name
    design.user = user
    design.save!
    design.parse
    
    if profile
      result       = RubyProf.stop
      printer      = RubyProf::GraphHtmlPrinter.new(result)
      profile_file = '/tmp/profile.html'
      profile_html = File.new(profile_file, 'w+')
      printer.print(profile_html, {:min_percent => 10})
      profile_html.close
      Log.info "Profile data available at #{profile_file}"
    end
  end
end
