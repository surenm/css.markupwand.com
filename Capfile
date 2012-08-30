ssh_options[:forward_agent] = true
default_run_options[:shell] = '/bin/bash'
logger.level = Logger::DEBUG

load 'deploy' if respond_to?(:namespace) # cap2 differentiator
Dir['vendor/gems/*/recipes/*.rb','vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }

# RVM shit
$:.unshift(File.expand_path('./lib', ENV['rvm_path']))
require "rvm/capistrano"
set :rvm_ruby_string, '1.9.2'
set :rvm_type, :user

# overrides
namespace :deploy do
  task :start do
    run "source /home/ubuntu/.rvm/scripts/rvm && cd #{current_path} && foreman start web_daemon"
  end

  task :stop do
    run "kill -QUIT `cat /tmp/unicorn.pid`"
  end
  
  task :restart do 
    if File.exists? '/tmp/unicorn.pid'
      run "kill -USR2 `cat /tmp/unicorn.pid`"
    else 
      deploy.start
    end
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
namespace :bundler do
  desc "Fetch bundle packages"
  task :bundle_new_release, :roles => :app do
    run "source /home/ubuntu/.rvm/scripts/rvm && cd #{release_path} && bundle install"
  end
end
after 'deploy:update_code', 'bundler:bundle_new_release'

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