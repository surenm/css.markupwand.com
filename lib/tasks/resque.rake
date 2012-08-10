require 'resque/tasks'

task "resque:setup" => :environment

Rake::Task["resque:work"].enhance ["install:psdjs"]

task "install:psdjs" do
  psdjs_dir = Rails.root.join 'tmp', 'psdjs'
  
  FileUtils.mkdir_p psdjs_dir if not Dir.exists? psdjs_dir
  FileUtils.cp Rails.root.join('lib', 'psdjs', 'package.json'), File.join(psdjs_dir, 'package.json')
  
  system "cd #{psdjs_dir}; npm install -d"
end