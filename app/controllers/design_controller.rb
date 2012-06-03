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
    uploaded_file = params[:files].first

    design = Design.create_from_upload uploaded_file, @user
    render :json => {:status => :failure}
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
end