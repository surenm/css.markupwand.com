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

    render :json => { :status => :success, :data => {}, :error => nil }
  end
  
  def update
    grid = Grid.find params[:id]

    if not params[:layer_id].nil?
      layer = Layer.find params[:layer_id] 
      layer.override_tag = params[:tag]
      layer.save!
    else
      grid.override_tag = params[:tag]
      grid.fix_children
      grid.save!
    end

    MarkupGeneratorJob.perform grid.design.id
    
    render :json => { :status => :success, :data => {}, :error => nil }
  end

end
