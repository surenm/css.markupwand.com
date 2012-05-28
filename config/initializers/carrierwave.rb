CarrierWave.configure do |config|
  config.grid_fs_connection = Mongoid.database
  config.storage = :grid_fs
end