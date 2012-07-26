class LoginController < ApplicationController
  def index
    @signup_enabled = !Constants::invite_gated?
  end

  def unauthorized

  end
end