class LandingPageController < ApplicationController
  def index
  end
  
  def getinvite
    @email = params[:email]
  end
end
