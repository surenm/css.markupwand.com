web:           bundle exec unicorn -p $PORT -c ./config/unicorn.rb
worker:        bundle exec rake resque:work QUEUE=uploader,screenshot,parser,pre_processor,generator,html_writer,screenshot,alerter
uploader:      bundle exec rake resque:work QUEUE=uploader
screenshot:    bundle exec rake resque:work QUEUE=screenshot
parser:        bundle exec rake resque:work QUEUE=parser
generator:     bundle exec rake resque:work QUEUE=generator
html_writer:   bundle exec rake resque:work QUEUE=html_writer
screenshot:    bundle exec rake resque:work QUEUE=screenshot
misc_tasks:    bundle exec rake resque:work QUEUE=misc_tasks
alerter:       bundle exec rake resque:work QUEUE=alerter
