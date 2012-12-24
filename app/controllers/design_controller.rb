require 'zip/zip'

class DesignController < ApplicationController
  before_filter :require_login, :except => [:upload_danger]
  before_filter :is_user_design, :except => [:new, :uploaded, :local_new, :local_uploaded, :index, :upload_danger]
  before_filter :require_admin_login, :only => [:download_psd, :increase_priority]

  private
  def is_user_design
    design_id = params[:id].split('-').last
    @design = Design.find design_id
      
    if not @user.admin and (@user != @design.user or @design.softdelete) 
      redirect_to dashboard_path
    end
  end
  
  public
  def new
    @new_design = Design.new
  end

  def uploaded
    design_data = params[:design]
    design      = Design.new :name => design_data[:name], :store => Store::get_S3_bucket_name
    design.user = @user
    design.save!
    
    Resque.enqueue UploaderJob, design.id, design_data
    redirect_to :action => :show, :id => design.safe_name
  end

  def intersecting_pairs
    pairs = @design.get_intersecting_pairs
    pairs_ids = []
    pairs.each do |left, right|
      if left.zindex < right.zindex
        type = left.bounds.crop_type right.bounds
      else
        type = right.bounds.crop_type left.bounds
      end

      pairs_ids.push({:left => left.uid, :right => right.uid, :type => type})
    end
    render :json => pairs_ids.to_json
  end

  def delete_layer
    uid = params[:uid]
    @design.init_sif
    @design.sif.layers.delete uid.to_i
    @design.sif.reset_calculated_data
    @design.sif.save!
    @design.regroup
    render :json => {:status => 'OK'}
  end

  def crop_layer
    left      = params[:left].to_i
    right     = params[:right].to_i
    crop_type = params[:type]
    left_layer  = @design.layers[left]
    right_layer = @design.layers[right]

    old_bounds  = {:left => left_layer.bounds, :right => right_layer.bounds}

    if left_layer.zindex < right_layer.zindex
      left_layer.crop_layer right_layer, crop_type
    else
      right_layer.crop_layer left_layer, crop_type
    end

    @design.sif.reset_calculated_data
    @design.sif.save!
    @design.regroup

    if old_bounds[:left] != @design.layers[left].bounds
      data = { :left => @design.layers[left].bounds }
    elsif old_bounds[:right] != @design.layers[right].bounds
      data = { :left => @design.layers[left].bounds }
    else
      data = {}
    end

    render :json => {:status => 'OK', :data => data}
  end

  def merge_layer
    left      = params[:left]
    right     = params[:right]
    left_layer  = @design.layers[left.to_i]
    right_layer = @design.layers[right.to_i]

    if left_layer.zindex < right_layer.zindex
      left_layer.merge_layer right_layer
      deleted = right_layer.uid
      left_out = left_layer.uid
      new_bounds = left_layer.bounds 
    else
      right_layer.merge_layer left_layer
      deleted = left_layer.uid
      left_out = right_layer.uid
      new_bounds = left_layer.bounds
    end

    render :json => {:status => 'OK', :data => {:deleted => deleted, :left_out => left_out, :new_bounds => new_bounds}}
  end
  
  def set_rating
    if params[:rate] == "true"
      @design.rating = true
      @design.save!
    elsif params[:rate] == "false"
      @design.rating = false
      @design.save!
    end

    if params[:redirect_url]
      redirect_to params[:redirect_url]
    else
      redirect_to :action => :preview, :id => @design.safe_name
    end
    
  end

  def local_new
    @design = Design.new
  end

  def local_uploaded
    file_name   = params[:design]["file"].original_filename
    design      = Design.new :name => file_name
    if @user.nil?
      design.user = User.find_by_email params[:email]
    else
      design.user = @user
    end

    design.file = params[:design]["file"]
    design.save!

    safe_basename = Store::get_safe_name File.basename(file_name, ".psd")
    safe_filename = "#{safe_basename}.psd"
    destination_file = File.join design.store_key_prefix, safe_filename
    Store.save_to_store design.file.current_path, destination_file
    
    design.psd_file_path = destination_file
    design.save!
    
    design.push_to_processing_queue
    
    redirect_to :action => :show, :id => design.safe_name
  end

  def replace_dom
    if params['source_node'] and params['target_node']
      target_grids = params['target_node'].split ","
      target_grids.each do |target_grid|
        target_grid = @design.grids[target_grid]
        target_grid.replace_grid_contents params['source_node']
      end

      # Pick any grid and finish the global grouping queue grouping
      # and generate the markup.
      @design.grids[target_grids.first].finish_grid_replacement

      redirect_to :action => :show, :id => @design.safe_name
    end

  end

  def images
    if params['layer']
      @renamed_files = []
      params['layer'].each do |uid, image_name|
        if @design.layers[uid.to_i].image_name != image_name
          original_name = @design.layers[uid.to_i].image_name
          final_name    = image_name
          @design.layers[uid.to_i].image_name = image_name
          Store::rename_file File.join(@design.store_extracted_key, "assets", "images", original_name), File.join(@design.store_extracted_key, "assets", "images", final_name)
          Store::rename_file File.join(@design.store_generated_key, "assets", "images", original_name), File.join(@design.store_generated_key, "assets", "images", final_name)
          Store::rename_file File.join(@design.store_published_key, "assets", "images", original_name), File.join(@design.store_published_key, "assets", "images", final_name)
          @renamed_files.push image_name
        end
      end
  
      @design.save_sif!
      @success = true
      @design.reparse
    end
    remote_file_path = @design.get_sif_file_path
    @sif_file = JSON.parse File.read Store::fetch_object_from_store remote_file_path
  end
  
  def index
    @status_class = Design::STATUS_CLASS
    @designs = @user.designs.where(:softdelete => false).sort do |a, b|
      b.created_at <=> a.created_at
    end

    #In case the user wants to upload a new design...
    @new_design = Design.new
  end
  
  def show
    @completed = (@design.status == Design::STATUS_COMPLETED)
    respond_to do |format|
      format.html
      format.json { render :json => @design.json_data }
    end
  end

  def edit
    @grids  = {}
    @layers = {}

    @design.grids.each do |id, data|
      @grids[id]  = { :id    => id,
                      :class => data.style.generated_selector,
                      :type  => 'grid',
                      :tag   => data.tag,
                      :css   => data.style.normal_css }
    end

    @design.layers.each do |id, data|
      @layers[id] = { :id    => id,
                      :class => data.generated_selector,
                      :type  => 'grid',
                      :tag   => data.tag_name }
    end
  end

  def save_edits
    dom_json = JSON.parse params['dom_json']
    layers   = dom_json['layer']
    grids    = dom_json['grid']
    layers.each do |id, layer_data|
      @design.layers[id.to_i].generated_selector = layer_data['class']
    end

    grids.each do |id, grid_data|
      @design.grids[id].style.generated_selector = grid_data['class']
      @design.grids[id].style.normal_css         = grid_data['css']
    end

    @design.save_sif!
    @design.push_to_generation_queue
  
    redirect_to :action => :show, :id => @design.safe_name
  end
  
  def preview
    if @design.status != Design::STATUS_COMPLETED
      redirect_to :action => :show, :id => @design.safe_name
    end

    if @user.admin?
      @next = Design.where(:created_at.lt => @design.created_at, :status=> 'completed').order_by([[:created_at, :desc]]).first
      @prev = Design.where(:created_at.gt => @design.created_at, :status=> 'completed').order_by([[:created_at, :asc]]).first
    end

  end

  def fonts_upload
    saveable_fonts = {}
    params['font'].each do |font, url|
      if not url.empty?
        filetype = FontMap.filetype(params['font_name'][font])
        saveable_fonts[font] = { :url => url, :name => params['font_name'][font], :type => filetype }
      end
    end

    saveable_fonts.each do |font, data|
      filename = font + '.' + data[:type].to_s
      saveable_fonts[font][:filename] = filename
      generated_url = File.join @design.store_generated_key, "assets", "fonts", filename
      published_url = File.join @design.store_published_key, "assets", "fonts", filename
      Store::write_from_url generated_url, data[:url]
      Store::write_from_url published_url, data[:url]

      user_font_exists = @user.user_fonts.where(:fontname => font).length > 0

      if not user_font_exists
        user_font = UserFont.new :fontname => font, :filename => filename, :type => data[:type].to_s
        user_font.user = @user
        user_font.save_from_url data[:url] 
        user_font.save!
        @user.save!
      end
    end

    @design.font_map.update_downloaded_fonts(saveable_fonts)
    @design.font_map.save!
    @design.save!
    self.reextract
  end

  def fonts
    @missing_fonts = @design.font_map.missing_fonts
  end

  def download
    tmp_folder = Store::fetch_from_store @design.store_published_key
    zip_file   = Rails.root.join("tmp", "#{@design.safe_name}.zip")
    analytical.track "design_download"
    path = tmp_folder.to_s

    path.sub!(%r[/$],'')
    FileUtils.rm zip_file, :force=>true

    Zip::ZipFile.open(zip_file, 'w') do |zipfile|
      Dir["#{path}/**/**"].reject{|f|f==zip_file}.each do |file|
        zipfile.add(file.sub(path+'/',''),file)
      end
    end

    send_file zip_file, :disposition => 'inline'
  end
  
  def download_psd
    file = Store::fetch_object_from_store(@design.psd_file_path)
    send_file file, :disposition => 'inline'
  end
      
  def update
    GeneratorJob.perform @design.id
    render :json => {:status => :success}
  end
  
  def delete
    @design.delete
    redirect_to dashboard_path
  end
  
  def generated
    if params[:type] == "published"
      base_folder = @design.store_published_key
    elsif params[:type] == "processed"
      base_folder = @design.store_processed_key
    elsif params[:type] == "generated"
      base_folder = @design.store_generated_key
    elsif params[:type] == "extracted"
      base_folder = @design.store_extracted_key
    end

    remote_file = File.join base_folder, "#{params[:uri]}.#{params[:ext]}"
    temp_file   = Store::fetch_object_from_store remote_file

    send_file temp_file, :disposition => "inline"
  end
  
  def reprocess
    @design.reprocess
    redirect_to :action => :show, :id => @design.safe_name
  end

  def reextract
    @design.reextract
    redirect_to :action => :show, :id => @design.safe_name
  end

  def regroup
    @design.regroup
    redirect_to :action => :show, :id => @design.safe_name
  end
  
  def reparse
    @design.reparse
    redirect_to :action => :show, :id => @design.safe_name
  end

  def regenerate
    @design.regenerate
    redirect_to :action => :show, :id => @design.safe_name
  end
  
  def view_logs
    render :text => "Adingu! Ellaame udane venumaa! Logs will come soon in this page."
  end
  
  def view_json
    remote_file_path = @design.get_sif_file_path
    sif_file = Store::fetch_object_from_store remote_file_path

    send_file sif_file, :disposition => 'inline', :type => 'application/json'
  end

  def increase_priority
    @design.move_to_priority_queue
    redirect_to :action => :show, :id => @design.safe_name
  end

  def view_serialized_data
    render :json => @design.get_serialized_sif_data
  end

  def editor
    @height = @design.scaled_height
    @width = @design.scaled_width
  end

  def group_layers
    layers = params[:layers]
    @design.group_layers layers
    render :json => {:status => :success}
  end

end
