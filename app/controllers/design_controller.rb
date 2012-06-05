class DesignController < ApplicationController
  before_filter :require_login
  
  def new
    @uploader = Design.new.file
    @uploader.success_action_redirect = upload_callback_url
  end
  
  def index
    @designs = @user.designs.reverse
  end
  
  def upload
    source_file = params[:key]
    file_name = File.basename source_file

    design = Design.new :name => file_name
    design.user = @user
    
    destination_file = File.join design.store_key_prefix, file_name
    Store.copy_within_S3 source_file, destination_file
    
    design.psd_file_path = destination_file
    design.save!

    redirect_to :action => "index"
  end
  
  def show
    readable_id = params[:id]
    design_id = readable_id.split('-').last
    
    @design = Design.find design_id
    render :json => @design.attribute_data
  end
  
  def update
    render :json => {:status => :success}
  end
  
  def edit
    
  end
end