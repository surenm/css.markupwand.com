class AdminController < ApplicationController
  before_filter :require_admin_login
  
  def index
    Log.info params
    start_date = params.fetch "start_date",  Time.now - 20.days
    end_date = params.fetch "end_date", Time.now
    page = params.fetch "page", 0

    status = params.fetch "status", nil 
    user_email = params.fetch "user", nil
    design = params.fetch "design", ""
    design_id = design.split("-").last

    @query_args = {:created_at.gt => start_date, :created_at.lt => end_date}
    @query_args[:status] = status.to_sym if not status.nil? and not status == "all"

    all_designs = []

    @query_args = {:created_at.gt => start_date, :created_at.lt => end_date}
    @query_args[:status] = status.to_sym if not status.nil? and not status == "all"
    
    if not design_id.nil? and design_id != ""
      @designs = Design.where(:_id => design_id).page(page)
      all_designs = @designs
    else
      all_designs = Design.all
      if not user_email.nil?
        all_designs = Design.all
        user = User.find_by_email user_email
        all_designs = user.designs if not user.nil?
      end
      @designs = all_designs.where(@query_args).order_by([[:created_at, :desc]]).page(page)
    end

    @results_data = {}
    @results_data[:total_count] = all_designs.count
    @results_data[:status] = status if not status.nil?
    @results_data[:user] = user_email if not user_email.nil?
    @results_data[:design] = design if not design.empty?
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
end
