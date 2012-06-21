web: bundle exec unicorn -p $PORT -c ./config/unicorn.rb
uploader: bundle exec rake resque:work QUEUE=uploader
worker: bundle exec rake resque:work QUEUE=parser,generator
