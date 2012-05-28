class LandingPageController < ApplicationController
  def index
  end
  
  def getinvite
    @email = params[:email]
    users = User.where(:email => @email)
    if(users.size==0)
      name = @email
      name.slice!(/\@.*/)
      user = User.create!({:email=>@email, :name=>name})
      user.save
    end
  end
end
