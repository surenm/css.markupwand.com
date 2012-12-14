source 'https://rubygems.org'

ruby "1.9.2"

gem 'rails', '3.2.0'

# Base libraries
gem 'aws-sdk'
gem 'bson'
gem 'bson_ext'
gem 'execjs'
gem 'json'
gem 'kaminari'
gem 'log4r'
gem 'mongo'
gem 'mongoid'
gem 'multimap'
gem 'redis'
gem 'redis-store', '~> 1.0.0'
gem 'rest-client'
gem 'rmagick'
gem 'tidy_ffi'
gem 'therubyracer'
gem 'xml-simple'
gem 'rubyzip'
gem "bugsnag"
gem 'rubytree', '~> 0.8.3'

# Init command related gems
gem 'foreman'
gem 'unicorn'
gem 'god'

# Background processing libraries
gem 'resque', '1.21.0'
gem 'resque-history'
gem 'resque-cleaner'
gem 'resque-scheduler', :require => 'resque_scheduler'

# UI related gems
gem 'flot-rails'
gem 'jquery-rails', '2.0.2'

# File upload related gems
gem 'carrierwave'
gem 'carrierwave-mongoid'

# Login and user management 
gem 'devise'
gem 'omniauth-openid'
gem 'omniauth-google-apps'

# Chat notification
gem 'hipchat'

# asset gems
gem 'compass', ">= 0.12.alpha.4"
gem 'compass-rails'
gem 'sass-rails', '~> 3.2.4'
gem 'twitter-bootstrap-rails'
gem 'asset_sync'

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'coffee-rails', '~> 3.2.2'
  gem 'uglifier', '>= 1.0.3'
  gem 'yui-compressor'
end

group :deploy do
  gem 'capistrano'
  gem 'rvm-capistrano'
  gem 'capistrano-ext'
  gem 'capistrano-resque'
end

#Testing
group :test do
  gem 'rspec-rails'
  gem 'capybara'
  gem 'factory_girl_rails', "~> 3.0"
end

group :development do
  gem 'pry-rails'
  gem 'pry-stack_explorer'
  gem 'pry_debug'
  gem 'ruby-prof'
end

# monitoring and profiling
gem 'newrelic_rpm'
gem 'rpm_contrib'

# Analytics
gem 'analytical', :git => 'git://github.com/Goyaka/analytical.git'
