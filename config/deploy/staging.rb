set :application, "markupwand-beta"
set :domain, "www.markupwand.com" unless exists?(:domain)
set :branch, "master" unless exists?(:branch)
set :deploy_to, "/opt/#{domain}"

set :heroku_app, "markupwand-beta"
set :heroku_remote, "staging"

# Servers list
server "ec2-23-20-68-9.compute-1.amazonaws.com", :web, :app

namespace :deploy do  
  task :copy_staging_configs do 
    run "cp #{shared_path}/staging_env #{current_path}/.env"
  end
end

after 'deploy:create_symlink', 'deploy:copy_staging_configs'
