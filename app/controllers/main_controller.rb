class MainController < ApplicationController
  before_filter :require_login
  skip_before_filter :require_login, :only => :index
  
  def su
    redirect_to '/' if not current_user.admin
     
    if current_user.admin and params.has_key? 'email'
      Log.info params
      user = User.where(:email => params['email']).first
      sign_in_and_redirect user, :event => :authentication if user
    end
  end
end