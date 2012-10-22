set :application, "markupwand-beta"
set :domain, "www.markupwand.com" unless exists?(:domain)
set :branch, "master" unless exists?(:branch)
set :deploy_to, "/opt/#{domain}"

set :heroku_app, "markupwand-beta"
set :heroku_remote, "staging"

set :shell_user, `whoami`

# Servers list
server "beta-worker.markupwand.com", :web, :app, :resque_worker
set :workers, { "worker" => 2 }

namespace :deploy do
  task :begin do
    Helper.notify "#{shell_user} is pushing branch:#{branch} to Staging..."
  end
  
  task :copy_staging_configs do
    run "cp #{shared_path}/staging_env #{current_path}/.env"
  end
  
  task :complete do
    set :shell_user, `whoami`
    Helper.notify "#{shell_user} has completed staging push successfully."
  end
end

namespace :heroku do
  task :status do
    system "heroku ps --app markupwand-beta"
  end
end

after 'deploy:create_symlink', 'deploy:copy_staging_configs'
after 'deploy:copy_staging_configs', 'deploy:complete'