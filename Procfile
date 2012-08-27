web:           bundle exec unicorn -p $PORT -c ./config/unicorn.rb
worker:        bundle exec rake resque:work QUEUE=uploader,extractor,parser,pre_processor,generator,html_writer
uploader:      bundle exec rake resque:work QUEUE=uploader
extractor:     bundle exec rake resque:work QUEUE=extractor
parser:        bundle exec rake resque:work QUEUE=parser
generator:     bundle exec rake resque:work QUEUE=generator
html_writer:   bundle exec rake resque:work QUEUE=html_writer
misc_tasks:    bundle exec rake resque:work QUEUE=misc_tasks
