require 'capistrano/ext/multistage'
require 'capistrano-resque'
require 'hipchat'

default_run_options[:pty] = false
default_run_options[:shell] = false

module Helper
  def self.notify(message)    
    client = HipChat::Client.new('64b7653958a37adb2f41b49efdad33')
    client['Markupwand'].send('capistrano', message, :notify => true, :color => 'green')
  end
end

# Precompile assets when there is change to asset files
namespace :deploy do
  namespace :assets do
    task :precompile_cached, :roles => :web, :except => { :no_release => true } do
      from = source.next_revision(current_revision)
      if capture("cd #{latest_release} && #{source.local.log(from)} vendor/assets/ app/assets/ | wc -l").to_i > 0
        run %Q{cd #{latest_release} && #{rake} RAILS_ENV=#{rails_env} #{asset_env} assets:precompile}
      else
        logger.info "Skipping asset pre-compilation because there were no asset changes"
      end
    end

    task :precompile, :roles => :web, :except => { :no_release => true } do
      run %Q{cd #{latest_release} && #{rake} RAILS_ENV=#{rails_env} assets:precompile}
    end
  end
end

# Bundle install after new code 
namespace :install do
  desc "Fetch bundle packages"
  task :bundle, :roles => :app do
    run "source /home/ubuntu/.rvm/scripts/rvm && cd #{release_path} && bundle install"
  end
  
  desc "Install npm packages"
  task :npm, :roles => :app do
    psdjs_lib_dir = File.join release_path, 'lib', 'psd.js'  
    run "cd #{psdjs_lib_dir}; npm install -d"
  end
  
  desc "Symlink log and tmp directories"
  task :setup_tmp_dir do
    run "rm -rf #{current_path}/tmp"
    run "ln -s #{shared_path}/tmp #{current_path}/tmp"
  end
end

# overrides
namespace :web do
  task :start do
    run "cp #{shared_path}/staging_env #{current_path}/.env"
    run "source /home/ubuntu/.rvm/scripts/rvm && cd #{current_path} && foreman start web_daemon"
  end

  task :stop do
    run "kill -QUIT `cat /tmp/unicorn.pid`"
  end
  
  task :restart do
    run "cp #{shared_path}/staging_env #{current_path}/.env"
    run "if [ -f /tmp/unicorn.pid ]  ; then echo 'Restarting...'; kill -USR2 `cat /tmp/unicorn.pid`; else echo 'Starting...'; source /home/ubuntu/.rvm/scripts/rvm  && cd #{current_path} && foreman start web_daemon; fi"
  end
end

namespace :worker do
  task :start do
    run "god start -c /opt/www.markupwand.com/current/script/worker.god"
  end
  
  task :stop do
    run "god stop workers"
  end
  
  task :restart do
    run "god restart workers"
  end
  
  task :terminate do
    run "god terminate"
  end
  
  task :soft_terminate, :on_error => :continue do
    run "god terminate"
  end
  
  task :force_restart do
    worker.soft_terminate
    worker.start
  end
  
  task :status do
    run "god status"
  end
end

# Heroku pushes
namespace :heroku do
  task :push do
    if branch == "master"
      system "git push -f #{heroku_remote} master" 
    else
      system "git push -f #{heroku_remote} #{branch}:master" 
    end
  end
end