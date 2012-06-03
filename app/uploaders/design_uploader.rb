# encoding: utf-8

class DesignUploader < CarrierWave::Uploader::Base
  include CarrierWaveDirect::Uploader
  
  include ActiveModel::Conversion
  extend ActiveModel::Naming
end
