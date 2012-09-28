set :application, "markupwand"
set :domain, "www.markupwand.com" unless exists?(:domain)
set :branch, "master" unless exists?(:branch)
set :deploy_to, "/opt/#{domain}"

set :heroku_app, "markupwand"
set :heroku_remote, "production"


namespace :deploy do  
  task :copy_prod_configs do 
    run "cp #{shared_path}/prod_env #{current_path}/.env"
  end
end

after 'deploy:create_symlink', 'deploy:copy_prod_configs'
