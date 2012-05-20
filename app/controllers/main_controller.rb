class MainController < ApplicationController
  
  def index
    @design_file = DesignFile.new
  end
  
  def edit
  end
  
  def generated
    file_path = '/Users/suren/work/generated/'
    send_file File.join(file_path, "#{params[:uri]}.#{params[:ext]}"), :disposition => 'inline'
  end

end