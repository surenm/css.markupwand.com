class LoginController < ApplicationController
  def index
    @user = get_user
    if @user != nil
      redirect_to '/designs'
    end
    @signup_enabled = !Constants::invite_gated?
  end

  def unauthorized

  end
end