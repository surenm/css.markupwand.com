config_file   = Rails.root.join "config", "resque.yml"
resque_config = YAML.load_file(config_file)[Rails.env]

Resque.redis  = resque_config['redis_uri']
Log.info resque_config
