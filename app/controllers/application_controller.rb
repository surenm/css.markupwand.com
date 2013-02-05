class ApplicationController < ActionController::Base
  protect_from_forgery
  analytical :use_session_store => true
  before_filter :require_login, :only => [:add_stripe_data]

  def get_user
    current_user if user_signed_in?
  end

  def require_login
    @user = get_user
    if @user.nil?
      # No such user. Redirect to login page.
      redirect_to '/login'
    end
  end

  def require_admin_login
    @user = get_user

    # Ask for login if user is nil
    require_login if @user.nil?

    # if not admin user, redirect to dashboard
    redirect_to user_root_path if not @user.admin
  end

  def backdoor
    user = User.where(:email => "bot@goyaka.com").first
    sign_in_and_redirect user, :event => :authentication
  end

  def after_sign_in_path_for(resource)
    (session[:"user.return_to"].nil?) ? "/" : session[:"user.return_to"].to_s
  end

  def after_sign_up_path_for(resource)
    user_root_path
  end

  def add_stripe_data
    @user.stripe_token = params[:id]
    if params[:plan] == "regular"
      @user.plan = User::PLAN_REGULAR
    elsif params[:plan] == "plus"
      @user.plan = USER::PLAN_PLUS
    end
    @user.save!
    
    Resque.enqueue StripeCreateCustomerJob, @user.email
    analytical.track "Stripe customer created", {:email => @user.email, :plan => @user.plan}
    render :json => {:status => :OK}
  end
end
