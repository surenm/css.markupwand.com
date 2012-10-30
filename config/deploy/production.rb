set :application, "markupwand"
set :domain, "www.markupwand.com" unless exists?(:domain)
set :branch, "master" unless exists?(:branch)
set :deploy_to, "/opt/#{domain}"

set :heroku_app, "markupwand"
set :heroku_remote, "production"

set :shell_user, `whoami`

server "prod-worker.markupwand.com", :web, :app, :resque_worker
set :workers, { "worker" => 2 }

namespace :deploy do
  task :begin do
    Helper.notify "#{shell_user} is pushing branch:#{branch} to Production..."
  end
    
  task :copy_prod_configs do 
    run "cp #{shared_path}/prod_env #{current_path}/.env"
  end

  task :complete do
    set :shell_user, `whoami`
    Helper.notify "#{shell_user} has completed production push successfully."
  end
end

namespace :heroku do
  task :status do
    system "heroku ps --app markupwand"
  end
end

after 'deploy:create_symlink', 'deploy:copy_prod_configs'
after 'deploy:copy_prod_configs', 'worker:force_restart'
after 'worker:force_restart', 'deploy:complete'
