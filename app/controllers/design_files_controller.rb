class DesignFilesController < ApplicationController
  def create
    require 'pp'
    pp params
    @design_file = DesignFile.new
    @design_file.file = params['design_file']["file"]
    @design_file.file.store!
    @design_file.save!
    render :nothing => true
  end

  def serve
    gridfs_path = env["PATH_INFO"].gsub("/designs/", "")
    begin
      gridfs_file = Mongo::GridFileSystem.new(Mongoid.database).open(gridfs_path, 'r')
      self.response_body = gridfs_file.read
      self.content_type = gridfs_file.content_type
    rescue
      self.status = :file_not_found
      self.content_type = 'text/plain'
      self.response_body = ''
    end
  end
end