class GridsController < ApplicationController
  before_filter :require_login
  
  def index
    design_id = params[:design].split('-').last
    @design = Design.find design_id
    
    response_grids = @design.grids.collect do |grid_obj|
      grid_obj.attribute_data
    end
    render :json => response_grids
  end

  def show
    grid = Grid.find(params[:id])
    render :json => grid.attribute_data
  end
  
  def generate_markup
    design_id = params[:design].split('-').last
    @design = Design.find design_id
    
    CssParser::set_assets_root @design.assets_root_path

    @design.generate_markup

    render :json => { :success => true }
  end

end
