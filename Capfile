ssh_options[:forward_agent] = true
default_run_options[:shell] = '/bin/bash'
logger.level = Logger::INFO

set :keep_releases, 10

load 'deploy' if respond_to?(:namespace) # cap2 differentiator
Dir['vendor/gems/*/recipes/*.rb','vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }

# RVM shit
require "rvm/capistrano"
set :rvm_ruby_string, '1.9.2'
set :rvm_type, :user

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
after 'deploy:create_symlink', 'deploy:assets:precompile_cached'

# Bundle install after new code 
namespace :install do
  desc "Fetch bundle packages"
  task :bundle, :roles => :app do
    run "source /home/ubuntu/.rvm/scripts/rvm && cd #{release_path} && bundle install"
  end
  
  desc "Install npm packages"
  task :npm, :roles => :app do
    psdjs_lib_dir = File.join current_path, 'vendor', 'psdjs'  
    run "cd #{psdjs_lib_dir}; npm install -d"
  end
  
  desc "Symlink log and tmp directories"
  task :setup_tmp_dir do
    run "rm -rf #{current_path}/tmp"
    run "ln -s #{shared_path}/tmp #{current_path}/tmp"
  end
end
after 'deploy:create_symlink', 'install:bundle'
after 'deploy:create_symlink', 'install:npm'
after 'deploy:create_symlink', 'install:setup_tmp_dir'

# Application
set :application, "markupwand"

set :domain, "www.markupwand.com" unless exists?(:domain)
set :branch, "master" unless exists?(:branch)
set :deploy_to, "/opt/#{domain}"

set :user, "ubuntu"
set :use_sudo, false

# Set the domain to which we have to push
set :scm, :git
set :repository, "git@github.com:Goyaka/transformers-web.git"
set :branch, "master" unless exists?(:branch)
set :git_enable_submodules, 1
set :deploy_via, :remote_cache

# Servers list
server "ec2-23-20-68-9.compute-1.amazonaws.com", :web, :app