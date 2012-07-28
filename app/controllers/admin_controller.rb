class AdminController < ApplicationController
  before_filter :require_admin_login
  
  def index
    Log.info params
    start_date = params.fetch "start_date",  Time.now - 20.days
    end_date = params.fetch "end_date", Time.now
    page = params.fetch "page", 0

    status = params.fetch "status", nil 
    user_email = params.fetch "user", nil

    all_designs = Design.all
    if not user_email.nil?
      user = User.find_by_email user_email
      if not user.nil? 
        all_designs = user.designs
      end
    end

    @query_args = {:created_at.gt => start_date, :created_at.lt => end_date}
    @query_args[:status] = status.to_sym if not status.nil? and not status == "all"
    
    @designs = all_designs.where(@query_args).page(page)
  end
  
  def reprocess
    designs = current_user.designs
    designs.each do |design|
      design.reprocess
    end
    redirect_to dashboard_path
  end
  
  def reparse
    designs = current_user.designs

    designs.each do |design|
      design.reparse
    end
    redirect_to dashboard_path
  end
  
  def regenerate
    designs = current_user.designs
    
    designs.each do |design|
      design.regenerate
    end
    redirect_to dashboard_path
  end

  # Returns the entire 
  def download_psd
    if params[:id] and not Rails.env.development?
      design = Design.find params[:id]
      file = Store::fetch_object_from_store(design.psd_file_path)
      send_file file, :disposition => 'inline'
    else
      render :status => :forbidden, :text => "Forbidden"
    end
  end
end
