class GridsController < ApplicationController
  def index
    @design = Design.find params[:design]
    
    response_grids = @design.grids.collect do |grid_obj|
      grid_obj.attribute_data
    end
    render :json => response_grids
  end

  def show
    grid = Grid.find(params[:id])
    render :json => grid.attribute_data
  end

  # GET /grids/new
  # GET /grids/new.json
  def new
    @grid = Grid.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @grid }
    end
  end

  # GET /grids/1/edit
  def edit
    @grid = Grid.find(params[:id])
  end

  # POST /grids
  # POST /grids.json
  def create
    @grid = Grid.new(params[:grid])

    respond_to do |format|
      if @grid.save
        format.html { redirect_to @grid, notice: 'Grid was successfully created.' }
        format.json { render json: @grid, status: :created, location: @grid }
      else
        format.html { render action: "new" }
        format.json { render json: @grid.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /grids/1
  # PUT /grids/1.json
  def update
    @grid = Grid.find(params[:id])

    respond_to do |format|
      if @grid.update_attributes(params[:grid])
        format.html { redirect_to @grid, notice: 'Grid was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @grid.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /grids/1
  # DELETE /grids/1.json
  def destroy
    @grid = Grid.find(params[:id])
    @grid.destroy

    respond_to do |format|
      format.html { redirect_to grids_url }
      format.json { head :no_content }
    end
  end
end
