class LandingPageController < ApplicationController
  def index
    if user_signed_in?
      redirect_to '/designs'
    end
  end
  
  def getinvite
    @email = params[:email]
    unless @email.nil?
    users = User.where(:email => @email)
      if(users.size==0)
        name = @email.split("@")[0]
        user = User.create!({:email=>@email, :name=>name})
        user.save
      end
    end
  end
end
