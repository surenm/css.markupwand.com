class LandingPageController < ApplicationController
  def index
    analytical.track '/'
  end

  def faq
    analytical.track '/faq'
  end

  def pricing
    analytical.track '/pricing'
    @user = get_user
  end
end
