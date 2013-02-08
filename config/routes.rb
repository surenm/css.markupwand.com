require 'resque-history/server'

TransformersWeb::Application.routes.draw do
  mount RailsAdmin::Engine => '/admin/data', :as => 'rails_admin'

  devise_for :users, :controllers => { :omniauth_callbacks => 'auth' }

  # Landing page controller views
  match '/faq'         => "landing_page#faq"
  match '/pricing'     => "landing_page#pricing"

  
  # Switch user
  devise_scope :user do
    get "login", :to => "devise/sessions#new"
    get "logout",:to => "devise/sessions#destroy"
    get "signup",:to => "devise/registrations#new"
  end

  match "/users/sign_in" => redirect("/login")
  match "/users/sign_up" => redirect("/signup")
  match "/users"         => redirect("/signup")

  # Dangerous controller route.
  if not Rails.env.production?
    match 'alaguisadude' => 'application#backdoor'
  end

  # payment related action
  match 'register-card' => 'application#add_stripe_data', :via => :post

  # design controller routes
  match 'designs' => 'design#index', :as => :user_root
  
  scope 'design' do 
    match 'new'       => 'design#new'
    match 'uploaded'  => 'design#uploaded', :as => :uploaded_callback
  
    scope ':id' do
      # get, put and edit designs
      match ''                 => 'design#show'
      match 'images'           => 'design#images'
      match 'image-rename'     => 'design#image_rename', :via => :post
      match 'image-crop'       => 'design#image_crop', :via => :post
      match 'image-reset'      => 'design#image_reset', :via => :post
      match 'replace-dom'      => 'design#replace_dom', :via => [:post, :get]
      match 'preview'          => 'design#preview'
      match 'download'         => 'design#download'
      match 'download-image/:layer_id'   => 'design#download_image'
      match 'update'           => 'design#update'
      match 'fonts'            => 'design#fonts'
      match 'fonts_upload'     => 'design#fonts_upload'
      match 'delete'           => 'design#delete'
      match 'set-rating'       => 'design#set_rating'
      
      # admin actions to regenerate stuff
      match 'reprocess'         => 'design#reprocess'
      match 'reextract'         => 'design#reextract'
      match 'regroup'           => 'design#regroup'
      match 'download-psd'      => 'design#download_psd'
      match 'full-conversion'   => 'design#conversion'
      
      # convinience methods to view logs, dom
      match 'view-json'  => 'design#view_json'
      match 'view-serialized-data' => 'design#view_serialized_data'

      # editor related activities
      match 'editor' => 'design#editor'
      match 'group-layers' => 'design#group_layers', :via => :post

      # intersections
      match 'intersecting-pairs' => 'design#intersecting_pairs'
      match 'delete-layer' => 'design#delete_layer', :via => :post
      match 'crop-layer' => 'design#crop_layer', :via => :post
      match 'merge-layer' => 'design#merge_layer', :via => :post
    end
  end

  # Proxy method to view generated files
  match ':type/:id/*uri.*ext' => 'design#generated'

  # admin actions for setting up testing
  match 'admin'            => 'admin#index', :as => :admin_path
  match 'admin/su'         => 'admin#su'
  match 'admin/save_tag'   => 'admin#save_tag', :via => :post
  match 'admin/stats'      => 'admin#stats'
 
  mount Resque::Server.new, :at => "/resque"
  
  # Main page redirects to index
  root :to => 'landing_page#index'
end
