class MainController < ApplicationController
  before_filter :require_login
  skip_before_filter :require_login, :only => :index

end