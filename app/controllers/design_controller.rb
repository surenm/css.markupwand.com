class DesignController < ApplicationController
  before_filter :require_login, :except => [:upload_danger]
  before_filter :is_user_design, :except => [:new, :uploaded, :local_new, :local_uploaded, :index, :upload_danger]
  
  private
  def is_user_design
    design_id = params[:id].split('-').last
    @design = Design.find design_id
      
    if (@design.nil? or @user != @design.user) and (@design.user.email != 'gallery@markupwand.com')
      redirect_to :action => index 
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
  
  def local_new
    @design = Design.new
  end
  
  def local_uploaded
    file_name   = params[:design]["file"].original_filename
    design      = Design.new :name => file_name
    design.user = @user    
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
  
  def index
    @status_class = Design::STATUS_CLASS
    @designs = @user.designs.sort do |a, b|
      b.created_at <=> a.created_at
    end

    @first_visit = (!params['fv'].nil? and params['fv'].to_i == 1 and cookies[:already_visited].nil?)
    if @first_visit
      cookies[:already_visited] = { :value => "true", :expires => 1.week.from_now }
    end

    #In case the user wants to upload a new design...
    @new_design = Design.new
  end
  
  def show
    @completed = (@design.status == Design::STATUS_COMPLETED)
    respond_to do |format|
      format.html
      format.json { render :json => @design.attribute_data(true) }
    end
  end
  
  def edit
  end

  def edit_class
    @selector_name_map = @design.selector_name_map
  end

  def save_class
    params['class_map'].each do |lookup, value|
      lookup_key = lookup.gsub("'",'')
      @design.selector_name_map[lookup_key]['name'] = value
    end

    @design.class_edited = true
    @design.save!
    @design.write_html_job
    redirect_to :action => :show, :id => @design.safe_name
  end

  def save_widget_name

    if not params['widget_name'].empty?
      widget_name = params['widget_name'].downcase.gsub(" ", "-")
      @design.class_edited = true
      root_grid  = @design.get_root_grid
      class_name = root_grid.style_selector.generated_selector
      @design.selector_name_map[class_name] = {} if @design.selector_name_map[class_name].nil? 
      @design.selector_name_map[class_name]['name'] = widget_name
      @design.class_edited = true
      @design.save!
    end


    redirect_to :action => :edit_class, :id => @design.safe_name
  end
  
  def preview
    if @design.status != Design::STATUS_COMPLETED
      redirect_to :action => :show, :id => @design.safe_name
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
    @design.write_html_job
    
    redirect_to :action => :fonts, :id => @design.safe_name
  end

  def fonts
    @missing_fonts = @design.font_map.missing_fonts
  end

  def gallery
  end
  
  def download
    tmp_folder = Store::fetch_from_store @design.store_published_key
    tar_file   = Rails.root.join("tmp", "#{@design.safe_name}.tar.gz")

    system "cd #{tmp_folder} && tar -czvf #{tar_file} ."
    send_file tar_file, :disposition => 'inline'
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
    end

    remote_file = File.join base_folder, "#{params[:uri]}.#{params[:ext]}"
    temp_file   = Store::fetch_object_from_store remote_file

    send_file temp_file, :disposition => "inline"
  end
  
  def reprocess
    @design.reprocess
    redirect_to :action => :show, :id => @design.safe_name
  end
  
  def reparse
    @design.reparse
    redirect_to :action => :show, :id => @design.safe_name
  end

  def write_html
    @design.write_html_job
    redirect_to :action => :show, :id => @design.safe_name
  end

  def regenerate
    @design.regenerate
    redirect_to :action => :show, :id => @design.safe_name
  end
  
  def view_logs
    render :text => "Adingu! Ellaame udane venumaa! Logs will come soon in this page."
  end
  
  def view_dom
    root_grid = @design.get_root_grid
    render :json => root_grid.get_tree
  end 

  def view_json
    processed_filebasename = File.basename @design.processed_file_path

    remote_file_path = File.join @design.store_processed_key, processed_filebasename    
    processed_file   = Store::fetch_object_from_store remote_file_path

    send_file processed_file, :disposition => 'inline'
  end

  def upload_danger
    # Stupid security for now.
    if params[:secret] == '02b0c8ad8a141b04693e923b3d56a918'
      design_data = params[:design]
      design      = Design.new :name => design_data[:name], :store => Store::get_S3_bucket_name
      design.user = User.find_by_email(params[:email])
      design.save!
      
      Resque.enqueue UploaderJob, design.id, design_data

      render :json => {:status => 'OK'}
    else
      render :json => {:status => 'ERROR'}
    end

  end  
end