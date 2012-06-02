class DesignController < ApplicationController
  before_filter :require_login
  def index
    @designs = @user.designs.reverse
  end
  
  def upload
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