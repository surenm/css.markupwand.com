class Utils
  def self.process_test_file
    fptr = File.new "/tmp/mailgun.psd.json"
    json_data = fptr.read
    Analyzer.analyze json_data
  end
end