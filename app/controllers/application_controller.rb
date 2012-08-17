class ApplicationController < ActionController::Base
  protect_from_forgery
  analytical :use_session_store=>true

  def get_user
    current_user if user_signed_in?
  end

  def require_login
    @user = get_user
    if @user.nil?
      # No such user. Redirect to login page.
      redirect_to '/login'
    else 
      if not @user.enabled
        # User found but not yet enabled
        invite_request = InviteRequest.where :email => @user
        if invite_request.size == 0
          # No invite record yet. 
          redirect_to '/unauthorized'
        elsif invite_request.first.status != InviteRequest::APPROVED
          # Not approved yet
          redirect_to '/unauthorized'
        elsif Constants::invite_gated?
          # Invites are closed
          redirect_to '/unauthorized'
        end
      
        user_invite = InviteRequest.where("email" => @user.email).first
      
        if not user_invite.nil? and user_invite.status == InviteRequest::APPROVED
          # User is approved for invite request. Enable him/her.
          @user.enabled = true
          @user.save!
        end
        
        if not @user.enabled and not Constants::invite_gated?
          # Gate is open. Approve user
          @user.enabled = true
          @user.save!
        end
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
