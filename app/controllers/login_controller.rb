class LoginController < ApplicationController
  def index
    require_login
    if @user != nil
      redirect_to '/designs'
    end
    @signup_enabled = !Constants::invite_gated?
  end

  def unauthorized

  end
end