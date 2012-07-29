require 'resque-history/server'

TransformersWeb::Application.routes.draw do
  devise_for :users, :controllers => { :omniauth_callbacks => 'auth' }

  resources :grids
  # grid controllers
  match 'grids/update' => 'grids#generate_markup', :via => :post
  
  # Landing page controller views
  match '/getinvite' => "landing_page#getinvite"
  match '/about'     => "landing_page#about"
  
  # Switch user
  devise_scope :user do
    get "logout", :to => "devise/sessions#destroy"
  end

  match 'login' => 'login#index'
  match 'unauthorized' => 'login#unauthorized'
  
  # Dangerous controller route.
  if not Rails.env.production?
    match 'alaguisadude' => 'application#backdoor'
  end

  # design controller routes
  match 'designs'         => 'design#index', :as => :dashboard

  if Constants::store_remote?
    match 'design/new'       => 'design#new'
    match 'design/uploaded'  => 'design#uploaded', :as => :uploaded_callback
    match 'design/upload_danger'  => 'design#upload_danger'
  else
    match 'design/new'       => 'design#local_new'
    match 'design/uploaded'  => 'design#local_uploaded', :as => :uploaded_callback
    match 'design/upload_danger'  => 'design#upload_danger'
  end
  
  # get, put and edit designs
  match 'design/:id'                  => 'design#show'
  match 'design/:id/edit'             => 'design#edit_class'
  match 'design/:id/edit-advanced'    => 'design#edit'
  match 'design/:id/save_class'       => 'design#save_class', :via => :post
  match 'design/:id/save_widget_name' => 'design#save_widget_name', :via => :post
  match 'design/:id/preview'          => 'design#preview'
  match 'design/:id/gallery'          => 'design#gallery'
  match 'design/:id/download'         => 'design#download'
  match 'design/:id/update'           => 'design#update'
  match 'design/:id/fonts'            => 'design#fonts'
  match 'design/:id/fonts_upload'     => 'design#fonts_upload'
  match 'design/:id/delete'           => 'design#delete'
  
  # admin actions to regenerate stuff
  match 'design/:id/reprocess'    => 'design#reprocess'
  match 'design/:id/reparse'      => 'design#reparse'
  match 'design/:id/regenerate'   => 'design#regenerate'
  match 'design/:id/write_html'   => 'design#write_html'
  match 'design/:id/download-psd' => 'design#download_psd'
  match 'design/:id/pq'           => 'design#increase_priority'
  
  # convinience methods to view logs, dom
  match 'design/:id/view-logs'  => 'design#view_logs'
  match 'design/:id/view-dom'   => 'design#view_dom'
  match 'design/:id/view-json'  => 'design#view_json'
  
  # Proxy method to view generated files
  match ':type/:id/*uri.*ext' => 'design#generated'

  # admin actions for setting up testing
  match 'admin'            => 'admin#index', :as => :admin_path
  match 'admin/reprocess'  => 'admin#reprocess'
  match 'admin/reparse'    => 'admin#reparse'
  match 'admin/regenerate' => 'admin#regenerate'
  match 'admin/su'         => 'admin#su'

  # TODO: add admin authentication for Admin URL's 
  mount Resque::Server.new, :at => "/resque"

  # tutorial page
  match 'start' => 'tutorials#index'
  
  # Main page redirects to index
  root :to => 'landing_page#index'
end