web:           bundle exec unicorn_rails -c ./config/unicorn_heroku.rb
web_daemon:    bundle exec unicorn_rails -c ./config/unicorn.rb -D 
worker:        bundle exec rake resque:work QUEUE=uploader,extractor,parser,generator,misc_tasks
uploader:      bundle exec rake resque:work QUEUE=uploader
extractor:     bundle exec rake resque:work QUEUE=extractor
parser:        bundle exec rake resque:work QUEUE=parser
generator:     bundle exec rake resque:work QUEUE=generator
misc_tasks:    bundle exec rake resque:work QUEUE=misc_tasks