class MainController < ApplicationController
  
  def index
    @design_file = DesignFile.new
  end
  
  def edit
  end
  
  def generated
    # TODO: Implement user ACL logic here
    file_path = File.absolute_path File.join Rails.root.to_s, "..", "generated"
    send_file File.join(file_path, "#{params[:uri]}.#{params[:ext]}"), :disposition => 'inline'
  end

end