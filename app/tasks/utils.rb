class Utils
  def self.process_test_file
    self.process_file "/tmp/mailgun.psd.json"
  end
  
  def self.process_file(file_name)
    Log.info "Beginning to process #{file_name}..."
    fptr = File.new file_name
    json_data = fptr.read
    Analyzer.analyze json_data
    Log.info "Successfully completed processing #{file_name}."
  end
end