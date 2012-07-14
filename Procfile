web:        bundle exec unicorn -p $PORT -c ./config/unicorn.rb
worker:     bundle exec rake resque:work QUEUE=parser,generator
uploader:   bundle exec rake resque:work QUEUE=uploader
parser:     bundle exec rake resque:work QUEUE=parser
generator:  bundle exec rake resque:work QUEUE=generator
slogger:    bundle exec rake resque:work QUEUE=uploader,parser,generator
