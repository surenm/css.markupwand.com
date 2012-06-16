class LandingPageController < ApplicationController
  def index
    if get_user
      # Redirect if logged in
      redirect_to 'design#index'
    end
  end
  
  def getinvite
    @email = params[:email]
    users = User.where(:email => @email)
    if(users.size==0)
      name = @email.split("@")[0]
      user = User.create!({:email=>@email, :name=>name})
      user.save
    end
  end
end
