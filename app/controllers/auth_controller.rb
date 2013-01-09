class AuthController < Devise::OmniauthCallbacksController
  include Devise::Controllers::Rememberable
  
  def after_omniauth_failure_path_for(scope)
    root_path
  end
  
  def after_sign_in_path_for(resource)
    return user_root_path
  end

  def after_sign_up_path_for(resource)
    return user_root_path
  end

  def admin
    omniauth = request.env["omniauth.auth"]
    user = User.find_or_create_admin_user omniauth
    sign_in_and_redirect user, :event => :authentication
  end

  def google_openid
    omniauth = request.env["omniauth.auth"]
    user = User.find_or_create_google_user omniauth
    sign_in_and_redirect user, :event => :authentication
  end
end