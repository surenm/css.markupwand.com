set :application, "markupwand"
set :domain, "css.markupwand.com" unless exists?(:domain)
set :branch, "css.markupwand.com"
set :deploy_to, "/opt/#{domain}"

set :heroku_app, "css-markupwand"
set :heroku_remote, "css.mw"

set :shell_user, `whoami`

server "beta-worker.markupwand.com", :web, :app, :resque_worker
set :workers, { "worker" => 2 }

namespace :deploy do
  task :begin do
    Helper.notify "#{shell_user} is pushing branch:#{branch} to css.markupwand.com..."
  end
    
  task :copy_cssmw_configs do 
    run "cp #{shared_path}/cssmw_env #{current_path}/.env"
  end

  task :complete do
    set :shell_user, `whoami`
    Helper.notify "#{shell_user} has completed css.markupwand.com push successfully."
  end
end

namespace :heroku do
  task :status do
    system "heroku ps --app css-markupwand"
  end

  task :config do 
    system "heroku config --app css-markupwand"
  end
end

after 'deploy:create_symlink', 'deploy:copy_cssmw_configs'
after 'deploy:copy_prod_configs', 'worker:force_restart'
after 'worker:force_restart', 'deploy:complete'
