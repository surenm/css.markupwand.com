web:           bundle exec unicorn_rails -c ./config/unicorn.rb
web_daemon:    bundle exec unicorn_rails -c ./config/unicorn.rb -D 
worker:        bundle exec rake resque:work QUEUE=uploader,extractor,parser,generator,html_writer
uploader:      bundle exec rake resque:work QUEUE=uploader
extractor:     bundle exec rake resque:work QUEUE=extractor
parser:        bundle exec rake resque:work QUEUE=parser
generator:     bundle exec rake resque:work QUEUE=generator
html_writer:   bundle exec rake resque:work QUEUE=html_writer
misc_tasks:    bundle exec rake resque:work QUEUE=misc_tasks