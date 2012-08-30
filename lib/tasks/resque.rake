require 'resque/tasks'

task "resque:setup" => :environment

Rake::Task["resque:work"].enhance ["install:psdjs"]

task "install:psdjs" do
  psdjs_lib_dir = Rails.root.join 'vendor', 'psdjs'  
  system "cd #{psdjs_lib_dir}; npm install -d"
end