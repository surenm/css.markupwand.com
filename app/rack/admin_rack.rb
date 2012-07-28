class AdminRack  
  def initialize(app)
    @app = app
  end

  def call(env)
    user = env['warden'].authenticate(:scope => :user)
    if user && user.admin?
      @app.call(env) 
    else
      throw(:warden, :scope => :user, :message => "Unauthorized")
    end
  end
end