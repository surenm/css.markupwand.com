class LandingPageController < ApplicationController
  def index
    @pretty_print = true
  end

  def getinvite
    if !Constants.invite_gated? or !current_users.nil?
      redirect_to "/"
    end
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
        invite = InviteRequest.create({:email => @email, :requestor_ip => request.remote_ip})
        invite.save!
      end
    end
  end

  def faq
  end
end
