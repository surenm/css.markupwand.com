class DesignController < ApplicationController
  before_filter :require_login
  
  private
  def get_design(readable_design_id)
    design_id = readable_design_id.split('-').last
    Design.find design_id
  end 
  
  public
  def new
    @uploader = Design.new.file
    @uploader.success_action_redirect = uploaded_callback_url
  end
  
  def local_new
    @design = Design.new
  end
  
  def index
    @designs = @user.designs.reverse    
  end
  
  def uploaded
    source_file = params[:key]
    file_name = File.basename source_file

    design = Design.new :name => file_name
    design.user = @user
    
    destination_file = File.join design.store_key_prefix, file_name
    Store.copy_within_S3 source_file, destination_file
    
    design.psd_file_path = destination_file
    design.save!
    design.push_to_queue

    redirect_to :action => "index"
  end
  
  def local_uploaded
    file_name   = params[:design]["file"].original_filename
    design      = Design.new :name => file_name
    design.user = @user    
    design.file = params[:design]["file"]
    design.save!

    destination_file = File.join design.store_key_prefix, file_name
    Store.copy_within_local design.file.current_path, destination_file
    
    design.psd_file_path = destination_file
    design.save!
    
    design.push_to_queue
    
    redirect_to :action => "index"
  end
  
  def show
    @design = get_design params[:id]
    
    render :json => @design.attribute_data
  end
  
  def update
    @design = get_design params[:id]
    
    render :json => {:status => :success}
  end
  
  def edit
    @design = get_design params[:id]
    
    # TODO: Backbone needs a collection to reset to. Find a correct way to do this
    @designs = Array[@design.attribute_data]
  end
end