Dropbox::API::Config.app_key    = ENV['DROPBOX_APP_TOKEN']
Dropbox::API::Config.app_secret = ENV['DROPBOX_APP_SECRET']
Dropbox::API::Config.mode       = "dropbox"


Dropbox::OAUTH_TOKEN=ENV['DROPBOX_OAUTH_TOKEN']
Dropbox::OAUTH_TOKEN_SECRET=ENV['DROPBOX_OAUTH_SECRET']
Dropbox::UID = "2587550"