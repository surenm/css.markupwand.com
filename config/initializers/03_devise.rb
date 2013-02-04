# Use this hook to configure devise mailer, warden hooks and so forth.
# Many of these configuration options can be set straight in your model.
Devise.setup do |config|
  require 'devise/orm/mongoid'
  require 'openid/store/filesystem'

  # Enable admin login by default
  config.omniauth :google_apps, :store => OpenID::Store::Filesystem.new('/tmp'), :name => 'admin', :domain => "goyaka.com"
  
  # Enable google openid login
  config.omniauth :open_id, :store => OpenID::Store::Filesystem.new('/tmp'), :name => 'google_openid', :identifier => 'https://www.google.com/accounts/o8/id', :require => 'omniauth-openid'

  # TODO: Enable github authentication as well
  # config.omniauth :github, Constants::GITHUB['app_id'], Constants::GITHUB['app_secret'], :scope => Constants::GITHUB['app_scope']
  
  config.mailer_sender = "support@markupwand.com"
  
  config.case_insensitive_keys = [ :email ]

  config.strip_whitespace_keys = [ :email ]

  config.skip_session_storage = [:http_auth]

  config.stretches = Rails.env.test? ? 1 : 10

  config.sign_out_via = :delete
  
  config.timeout_in = 64.hours
  
  config.reset_password_within = 6.hours

  config.warden do |manager|
    manager.failure_app = CustomFailure
  end
end
