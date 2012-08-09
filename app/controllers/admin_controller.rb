class AdminController < ApplicationController
  before_filter :require_admin_login
  
  def index
    start_date = params.fetch "start_date",  Time.now - 20.days
    end_date = params.fetch "end_date", Time.now
    page = params.fetch "page", 0

    status     = params.fetch "status", nil 
    user_email = params.fetch "user", nil
    designs    = params.fetch "designs", ""
    tag        = params.fetch "tag", nil
    design_splits = designs.split(",")
    design_ids    = []
    design_splits.each do |design_item|
      design_id = design_item.strip.split('-').last
      if not design_id.nil? and not design_id.empty?
        design_ids.push design_id
      end
    end

    @query_args = {:created_at.gt => start_date, :created_at.lt => end_date}
    @query_args[:status] = status.to_sym if not status.nil? and not status == "all"


    @query_args = {:created_at.gt => start_date, :created_at.lt => end_date}
    @query_args[:status] = status.to_sym if not status.nil? and not status == "all"
    
    if not design_ids.empty? and not design_ids.length == 0
      all_designs = Design.where(:_id.in => design_ids)
    else
      all_designs = Design.all
      if not user_email.nil?
        all_designs = Design.all
        user = User.find_by_email user_email
        all_designs = user.designs if not user.nil?
      end
      all_designs = all_designs.where(@query_args).order_by([[:created_at, :desc]])
    end

    if not tag.nil?
      all_designs = all_designs.tagged_with(tag)
    end

    @designs = all_designs.page(page)

    @results_data = {}
    @results_data[:total_count] = all_designs.count
    @results_data[:status] = status if not status.nil?
    @results_data[:user] = user_email if not user_email.nil?
    @results_data[:design] = designs if not designs.empty?
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

  def su
    redirect_to '/' if not current_user.admin
    if current_user.admin and params.has_key? 'email'
      user = User.where(:email => params['email']).first
      sign_in_and_redirect user, :event => :authentication if user
    end
  end

end
