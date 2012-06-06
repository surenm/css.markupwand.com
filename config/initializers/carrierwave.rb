Fog.mock!
connection = Fog::Storage.new(:provider => 'AWS', 
:aws_access_key_id      => ENV['AWS_ACCESS_KEY_ID'],
:aws_secret_access_key  => ENV['AWS_SECRET_ACCESS_KEY']
)
connection.directories.create(:key => 'store_development')

CarrierWave.configure do |config|
  
  config.fog_credentials = {
    :provider               => 'AWS',
    :aws_access_key_id      => ENV['AWS_ACCESS_KEY_ID'],
    :aws_secret_access_key  => ENV['AWS_SECRET_ACCESS_KEY']
  }
  
  config.fog_directory  = "store_#{Rails.env}"
end