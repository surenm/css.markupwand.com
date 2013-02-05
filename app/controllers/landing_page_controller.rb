class LandingPageController < ApplicationController
  def index
  end

  def faq
  end

  def pricing
    @user = get_user
  end
end
