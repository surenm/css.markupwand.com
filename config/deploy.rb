require 'capistrano/ext/multistage'

# Hip chat notifications
require 'hipchat/capistrano'
set :hipchat_token, "64b7653958a37adb2f41b49efdad33"
set :hipchat_room_name, "Markupwand"
set :hipchat_announce, true # notify users?


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
namespace :deploy do
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