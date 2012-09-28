source 'https://rubygems.org'

ruby "1.9.2"

gem 'rails', '3.2.0'

gem 'bson'
gem 'bson_ext'
gem 'execjs'
gem 'flot-rails'
gem 'jquery-rails', '2.0.2'
gem 'json'
gem 'mongo'
gem 'mongoid'
gem 'therubyracer'
gem 'xml-simple'
gem 'log4r'
gem 'rmagick'
gem 'aws-sdk'
gem 'resque', '1.21.0'
gem 'resque-history'
gem 'resque-cleaner'
gem 'resque-scheduler', :require => 'resque_scheduler'
gem 'redis'
gem 'redis-store', '~> 1.0.0'
gem 'dalli' # Memcache
gem 'rest-client'
gem 'tidy_ffi'
gem 'multimap'
gem 'kaminari'
gem 'foreman'

# Deployment related gems
gem 'unicorn'

# Chat notification
gem 'hipchat'

#File upload related gems
gem 'carrierwave'
gem 'carrierwave-mongoid'

# Login and user management 
gem 'devise'
gem 'omniauth-openid'
gem 'omniauth-google-apps'

# asset gems
gem 'compass', ">= 0.12.alpha.4"
gem 'compass-rails'
gem 'sass-rails', '~> 3.2.4'
gem 'twitter-bootstrap-rails'
gem 'asset_sync'

#Analytics
gem 'analytical', :git => 'git://github.com/Goyaka/analytical.git'

# monitoring and profiling
group :production do
  gem 'newrelic_rpm'
end

#Testing
gem 'rspec-rails'
group :test do
  gem 'capybara'
  gem 'factory_girl_rails', "~> 3.0"
end

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'coffee-rails', '~> 3.2.2'
  gem 'uglifier', '>= 1.0.3'
  gem 'yui-compressor'
end

group :development do
  gem 'pry-rails'
  gem 'pry-stack_explorer'
  gem 'pry_debug'
  gem 'ruby-prof'
  gem 'capistrano'
  gem 'rvm-capistrano'
end

group :deploy do
  gem 'capistrano'
  gem 'capistrano-ext'
  gem 'capistrano-resque'
end

