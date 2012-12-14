web:           bundle exec unicorn_rails -p $PORT -c ./config/unicorn_heroku.rb
web_daemon:    bundle exec unicorn_rails -c ./config/unicorn.rb -D 
worker:        bundle exec rake resque:work QUEUE=worker
uploader:      bundle exec rake resque:work QUEUE=uploader
misc_tasks:    bundle exec rake resque:work QUEUE=misc_tasks