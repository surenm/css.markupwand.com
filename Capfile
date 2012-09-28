# Load dependencies
load 'deploy' if respond_to?(:namespace) # cap2 differentiator
Dir['vendor/gems/*/recipes/*.rb','vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }

# remove this line to skip loading any of the default tasks
load 'config/deploy' 

# Set logger level
logger.level = Logger::DEBUG

# Enable ssh agent forwarding
ssh_options[:forward_agent] = true

# Set the default bash shell for run commands on external server
default_run_options[:shell] = '/bin/bash'

# Just keep 10 releases on cleaning up
set :keep_releases, 10

# RVM shit
require "rvm/capistrano"
set :rvm_ruby_string, '1.9.2'
set :rvm_type, :user

# Application
set :user, "ubuntu"
set :use_sudo, false
set :scm, :git
set :repository, "git@github.com:Goyaka/transformers-web.git"
set :branch, "master" unless exists?(:branch)
set :git_enable_submodules, 1
set :deploy_via, :remote_cache

before 'deploy:update_code', 'heroku:push'

# After symlink is created, precompile assets
after 'deploy:create_symlink', 'deploy:assets:precompile_cached'

# Run one time set up commands after creating symlink
after 'deploy:create_symlink', 'install:bundle'
after 'deploy:create_symlink', 'install:npm'
after 'deploy:create_symlink', 'install:setup_tmp_dir'