class Utils
  def self.process_test_file
    fptr = File.new "/tmp/Dashboard.psd.json"
    json_data = fptr.read
    Analyzer.analyze json_data
  end
end