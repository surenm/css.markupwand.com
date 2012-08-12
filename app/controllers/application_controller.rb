class ApplicationController < ActionController::Base
  protect_from_forgery
  analytical :use_session_store=>true

  def get_user
    current_user if user_signed_in?
  end

  def require_login
    @user = get_user
    if @user.nil?
      # TODO: Not relocating to proper url. Fix that. Not sure if its a bug.
      redirect_to user_omniauth_authorize_path :google_openid, :origin => request.fullpath
    elsif not @user.enabled
      invite_request = InviteRequest.where("email" => @user.email)
      if not Constants::invite_gated? or invite_request.first.status == InviteRequest::APPROVED
        @user.enabled = true
        @user.save!
      elsif invite_request.size == 0 or invite_request.first.status != InviteRequest::APPROVED
        @user = nil
        redirect_to '/unauthorized'
      end
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

  def after_sign_in_path_for(resource)
    (session[:"user.return_to"].nil?) ? "/" : session[:"user.return_to"].to_s
  end
end
