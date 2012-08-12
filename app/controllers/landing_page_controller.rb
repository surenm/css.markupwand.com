class LandingPageController < ApplicationController
  def index
    if user_signed_in?
      redirect_to '/designs'
    end
  end

  def getinvite
    @email = params[:email]
    @user_exists = false
    @user_enabled = false
    @already_requested_invite = false
    unless @email.nil?
      user = User.where(:email => @email)
      invites = InviteRequest.where(:email => @email)
      if user.size > 0
        @user_exists = true
        @user_enabled = user.first.enabled
      elsif invites.size > 0
        @already_requested_invite = true
      elsif (invites.size == 0 && user.size == 0)
        invite = InviteRequest.create({:email => @email})
        invite.save!
      end
    end
  end
end
