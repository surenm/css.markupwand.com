require 'resque/tasks'
require 'resque_scheduler/tasks'


task "resque:setup" => :environment
task "resque:scheduler" => :environment

task "install:psdjs" do
  psdjs_lib_dir = Rails.root.join 'lib', 'psdjs'
  psdjs_tmp_dir = Rails.root.join 'tmp', 'psdjs'
  
  FileUtils.mkdir_p psdjs_tmp_dir if not Dir.exists? psdjs_tmp_dir
  
  Dir["#{psdjs_lib_dir}/**"].each do |file| 
    basename = File.basename file
    FileUtils.cp file, File.join(psdjs_tmp_dir, basename)
  end
  
  system "cd #{psdjs_tmp_dir}; npm install -d"
end