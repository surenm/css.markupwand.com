require 'pp'
require 'open-uri'
class DesignFilesController < ApplicationController
  def create
    @design_file = DesignFile.new
    @design_file.file = params['design_file']["file"]
    @design_file.file.store!
    @design_file.status = DesignFile::UNASSIGNED
    @design_file.save!
    render :nothing => true
  end

  def serve
    file_path = params['path']
    if not params['format'].empty?
      file_path += "."+params['format']
    end
    file_obj = DesignFileUploader.fetch_file(file_path)
    if file_obj.nil?
      self.status = :file_not_found
      self.content_type = 'text/plain'
      self.response_body = ''  
    else
      self.response_body = file_obj.read
      self.content_type = file_obj.content_type
    end
  end
  
  def next_unprocessed
    next_file = DesignFile.where(status:DesignFile::UNASSIGNED).first
    filepath = next_file.get_file
    @response = Hash.new
    @response['file_path'] = filepath
    @response['file_name'] = File.basename filepath
    @response['process_timeout'] = DesignFile::STATUS_TIMEOUT
    @response['current_status'] = next_file.status
    
    #FIXME: This webserver would be running in the same box where photoshop is deployed for the time being. Should be made horizontally scalable later
    #Copying the file to a local filesystem for now, and setting the status to assigned
    
    open("/tmp/"+File.basename(filepath), 'wb') do |file|
      file << open("http://localhost:3000/designs/"+filepath).read
    end
    @response['local_file_path'] = "/tmp/"+File.basename(filepath)
    next_file.status = DesignFile::ASSIGNED
    
    #FIXME: Ugly code for the time being. To make work with Extendscript
    self.content_type = 'text/json'
    self.response_body = @response.to_json
  end
end