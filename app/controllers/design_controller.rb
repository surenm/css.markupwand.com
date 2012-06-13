class DesignController < ApplicationController
  before_filter :require_login, :except => [:processed]
  
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

    design = Design.new :name => file_name, :store => Store::get_S3_bucket_name
    design.user = @user
    
    
    destination_file = File.join design.store_key_prefix, file_name
    Store.copy_within_remote_store source_file, destination_file
    
    design.psd_file_path = destination_file
    design.save!
    design.push_to_processing_queue processed_callback_url

    redirect_to :action => "index"
  end
  
  def local_uploaded
    file_name   = params[:design]["file"].original_filename
    design      = Design.new :name => file_name
    design.user = @user    
    design.file = params[:design]["file"]
    design.save!

    destination_file = File.join design.store_key_prefix, file_name
    Store.save_to_store design.file.current_path, destination_file
    
    design.psd_file_path = destination_file
    design.save!
    
    design.set_status Design::STATUS_PROCESSING
    design.push_to_processing_queue processed_callback_url
    
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
  
  def processed
    design = get_design params[:design]
    design.set_status Design::STATUS_PROCESSED
    
    design.push_to_generation_queue
    render :json => {:status => :success}
  end
  
  def generated
    design = get_design params[:design]
    
    # ACL logic - if the current user is not owner of this design, redirect
    redirect_to :action => index if @user != design.user

    remote_file = File.join design.store_generated_key, "#{params[:uri]}.#{params[:ext]}"
    temp_file   = Store::fetch_object_from_store remote_file
    
    # Send the fetched file
    send_file temp_file, :disposition => 'inline'
  end
  
end