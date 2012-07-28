class AdminController < ApplicationController
  before_filter :require_admin_login
  
  def index
    @start_date = params.fetch "start_date",  Time.now - 100.days
    @end_date = params.fetch "end_date", Time.now
    @page = params.fetch "page", 0

    @designs = Design.all.where(:created_at.gt => @start_date, :created_at.lt => @end_date).page(@page)
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
  def download_psd_direct
    if params[:id] and not Rails.env.development?
      design = Design.find params[:id]
      file = Store::fetch_object_from_store(design.psd_file_path)
      send_file file, :disposition => 'inline'
    else
      render :status => :forbidden, :text => "Forbidden"
    end
  end

  # controller for downloading UI
  def download_psd
  end
end
