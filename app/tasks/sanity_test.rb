require 'fileutils'
class SanityTest
  def self.run(dir)
    files = Dir["#{dir}/**/*.psd.json"]
    files.each do |file|
      PageGlobals.data_dir = File.dirname file
      assets = Dir[PageGlobals.data_dir+"/**"]
      assets.each do |asset|
        FileUtils.cp asset, "/tmp/"+File.basename(asset)
      end
      begin
        Utils.process_file(File.basename file, '.psd.json')
        Log.info "==========================================="
      rescue
        Log.error $!
        Log.error("Failed to process #{File.basename file}")
      end
    end
  end
end