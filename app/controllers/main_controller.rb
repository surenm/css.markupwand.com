class MainController < ApplicationController
  before_filter :require_login
  skip_before_filter :require_login, :only => :index

  def generated
    # TODO: Implement user ACL logic here
    file_path = File.join Rails.root.to_s, "store", @user.email, params[:design], "generated"
    send_file File.join(file_path, "#{params[:uri]}.#{params[:ext]}"), :disposition => 'inline'
  end

end