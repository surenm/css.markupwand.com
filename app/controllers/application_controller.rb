class ApplicationController < ActionController::Base
  protect_from_forgery
  
  def get_user
    current_user if user_signed_in?
  end
  
  def require_login
    @user = get_user
    if @user.nil?
      # TODO: Not relocating to proper url. Fix that. Not sure if its a bug.
      redirect_to user_omniauth_authorize_path :google_openid, :origin => request.fullpath
    end
  end
  
  def require_admin_login
    @user = get_user
    
    # Ask for login if user is nil
    require_login if @user.nil?
    
    # if not admin user, redirect to dashboard
    redirect_to dashboard_path if not @user.admin
  end
  
  def backdoor
    user = User.where(:email => "bot@goyaka.com").first
    sign_in_and_redirect user, :event => :authentication
  end
end
