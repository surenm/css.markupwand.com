class Utils
  def self.process_test_file
    self.process_file '/tmp/mailgun.psd.json'
  end
  
  def self.process_file(file_name)
    user = User.find_by_email 'bot@goyaka.com'
    Log.debug user
    design = Design.new :processed_file_path => file_name
    design.user = user
    design.save!
    Log.debug design
    
    design.parse
  end
end
