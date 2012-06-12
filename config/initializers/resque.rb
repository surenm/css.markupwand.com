require 'resque/server'

config_file   = Rails.root.join "config", "resque.yml"
resque_config = YAML.load_file(config_file)[Rails.env]

uri = URI.parse(resque_config["redis_uri"])
Log.info uri
Resque.redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
