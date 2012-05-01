class MainController < ApplicationController
  
  def index
    @design_file = DesignFile.new
  end

end