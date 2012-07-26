class AdminController < ApplicationController
  before_filter :require_admin_login
  
  def index
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
