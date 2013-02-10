require 'zip/zip'

class DesignController < ApplicationController
  before_filter :require_login, :except => [:upload_danger]
  before_filter :is_user_design, :except => [:new, :uploaded, :local_new, :local_uploaded, :index]
  before_filter :require_admin_login, :only => [:download_psd, :delete]

  private
  def is_user_design
    design_id = params[:id].split('-').last
    @design = Design.find design_id
      
    if not @user.admin and (@user != @design.user or @design.softdelete) 
      redirect_to user_path
    end
  end
  
  public
  def new
    @new_design = Design.new
  end

  def uploaded
    design_data = params[:design]
    
    design = Design.new :name => design_data[:name]
    design = Design.new :name => design_data[:name]
    design.user = @user
    design.save!
    
    Resque.enqueue UploaderJob, design.id, design_data
    render :json => {:design => design.safe_name}
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
    
    design.push_to_extraction_queue
    
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

  def image_reset
    if params[:layer_id]
      @design.init_sif

      layer = @design.layers[params[:layer_id].to_i]
      image_name  = @design.layers[params[:layer_id].to_i].image_name

      destination  = File.join @design.store_extracted_key, "images", image_name
      source      = File.join @design.store_images_key, "#{layer.uid}.png"
      
      Store::copy_within_store source, destination
      
      render :json => {:status => 'SUCCESS'}
    else
      render :json => {:status => 'FAILED'}
    end
  end

  def image_crop 
    if params[:layer_id] and params[:h] and params[:w] and
      params[:x] and params[:y]

      x = params[:x].to_i
      y = params[:y].to_i
      w = params[:w].to_i
      h = params[:h].to_i

      @design.init_sif
      image_name  = @design.layers[params[:layer_id].to_i].image_name
      image_file  = File.join @design.store_extracted_key, "images", image_name
      current_image_path = Store::fetch_object_from_store(image_file)

      layer = @design.layers[params[:layer_id].to_i]

      current_image    = Image.read(current_image_path).first
      current_image.crop!(x, y, w, h)
      current_image.write(current_image_path)
      Store::save_to_store current_image_path, image_file

      render :json => {:status => 'SUCCESS'}
    else
      render :json => {:status => 'FAILED'}
    end
  end

  def image_rename
    if params[:pk] and params[:value]
      uid = params[:pk].to_i
      original_name = @design.layers[uid].image_name
      final_name = params[:value]

      if original_name != final_name
       @design.sif.layers[uid].image_name = final_name
       @design.sif.save! 

       src_file = File.join @design.store_extracted_key, "images", original_name
       destination_file = File.join @design.store_extracted_key, "images", final_name
       Store::rename_file src_file, destination_file

       data = {:status => "OK"}
      else
       data = { :status => "OK", :message => 'Same image name'}
      end
    else
      data = {:status => "FAILED"}
    end
    
    render :json => data
  end

  def images
    remote_file_path = @design.get_sif_file_path
    @sif_file = JSON.parse File.read Store::fetch_object_from_store remote_file_path
    @bg_contain = {}
    @design.layers.each do |uid, layer|
      if layer.type == Layer::LAYER_NORMAL
        if layer.bounds.width > 170 or layer.bounds.height > 170
          @bg_contain[uid] = true
        end
      else
        @bg_contain[uid] = false
      end
    end
  end
  
  def index
    @designs = @user.designs.where(:softdelete => false).sort do |a, b|
      b.created_at <=> a.created_at
    end

    ability = Ability.new @user
    @allow_new_designs = ability.can? :create, Design.new
  end

  def show
    respond_to do |format|
      format.html { render :template => 'css.mw/show' }
      format.json { render :json => @design.json_data }
    end
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
      published_url = File.join @design.store_published_key, "assets", "fonts", filename
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
    tmp_folder = Store::fetch_from_store File.join(@design.store_extracted_key, 'images')
    zip_file   = Rails.root.join("tmp", "#{@design.safe_name_prefix}.zip")
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

  def download_image
    if not params[:layer_id]
      render :text => "FAILURE"
    else
      @design.init_sif
      image_name  = @design.layers[params[:layer_id].to_i].image_name
      image_file  = File.join @design.store_extracted_key, "images", image_name
      copied_dest = Store::fetch_object_from_store(image_file)

      send_file copied_dest, :disposition => 'download', :filename => image_name
    end
  end
  
  def download_psd
    file = Store::fetch_object_from_store(@design.psd_file_path)
    send_file file, :disposition => 'inline'
  end
      
  def delete
    @design.delete
    redirect_to user_root_path
  end
  
  def generated
    if params[:type] == "published"
      base_folder = @design.store_published_key
    elsif params[:type] == "extracted"
      base_folder = @design.store_extracted_key
    elsif params[:type] == "images"
      base_folder = @design.store_images_key
    end

    remote_file = File.join base_folder, "#{params[:uri]}.#{params[:ext]}"
    temp_file   = Store::fetch_object_from_store remote_file
    send_file temp_file, :disposition => "inline"
  end

  def url
    if params[:type] == "published"
      base_folder = @design.store_published_key
    elsif params[:type] == "extracted"
      base_folder = @design.store_extracted_key
    elsif params[:type] == "images"
      base_folder = @design.store_images_key
    end

    remote_file = File.join base_folder, "#{params[:uri]}.#{params[:ext]}"
    url = Store::get_store_url_for_object remote_file
    redirect_to url
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
  
  def conversion
    Resque.enqueue ConversionJob, @design.id
    redirect_to :action => :show, :id => @design.safe_name
  end

  def view_json
    remote_file_path = @design.get_sif_file_path
    sif_file = Store::fetch_object_from_store remote_file_path

    send_file sif_file, :disposition => 'inline', :type => 'application/json'
  end

  def view_serialized_data
    render :json => @design.get_serialized_sif_data
  end

  def group_layers
    layers = params[:layers]
    @design.group_layers layers
    render :json => {:status => :success}
  end
end
