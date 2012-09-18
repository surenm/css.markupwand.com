require 'resque-history/server'

TransformersWeb::Application.routes.draw do
  devise_for :users, :controllers => { :omniauth_callbacks => 'auth' }

  resources :grids
  # grid controllers
  match 'grids/update' => 'grids#generate_markup', :via => :post
  
  # Landing page controller views
  match '/getinvite'   => "landing_page#getinvite"
  match '/about'       => "landing_page#about"
  match '/faq'         => "landing_page#faq"
  match '/limitations' => "landing_page#limitations"

  
  # Switch user
  devise_scope :user do
    get "login", :to => "devise/sessions#new"
    get "logout", :to => "devise/sessions#destroy"
    get "signup", :to => "devise/registrations#new"
  end

  match "/users/sign_in" => redirect("/login")
  match "/users/sign_up" => redirect("/signup")
  match "/users" => redirect("/signup")
  match "/start" => redirect("/")

  match 'unauthorized' => 'login#unauthorized'
  
  # Dangerous controller route.
  if not Rails.env.production?
    match 'alaguisadude' => 'application#backdoor'
  end

  # design controller routes
  match 'designs' => 'design#index', :as => :dashboard
  
  scope 'design' do 

    if Constants::store_remote?
      match 'new'       => 'design#new'
      match 'uploaded'  => 'design#uploaded', :as => :uploaded_callback
    else
      match 'new'       => 'design#local_new'
      match 'uploaded'  => 'design#local_uploaded', :as => :uploaded_callback
    end

    scope ':id' do
      # get, put and edit designs
      match ''                 => 'design#show'
      match 'edit'             => 'design#edit'
      match 'save_class'       => 'design#save_class', :via => :post
      match 'save_widget_name' => 'design#save_widget_name', :via => :post
      match 'preview'          => 'design#preview'
      match 'download'         => 'design#download'
      match 'update'           => 'design#update'
      match 'fonts'            => 'design#fonts'
      match 'fonts_upload'     => 'design#fonts_upload'
      match 'delete'           => 'design#delete'
      match 'set-rating'       => 'design#set_rating'
      
      # admin actions to regenerate stuff
      match 'reextract'    => 'design#reextract'
      match 'reparse'      => 'design#reparse'
      match 'regenerate'   => 'design#regenerate'
      match 'download-psd' => 'design#download_psd'
      
      # convinience methods to view logs, dom
      match 'view-logs'  => 'design#view_logs'
      match 'view-dom'   => 'design#view_dom'
      match 'view-json'  => 'design#view_json'
    end

  end

  # Proxy method to view generated files
  match ':type/:id/*uri.*ext' => 'design#generated'

  # admin actions for setting up testing
  match 'admin'            => 'admin#index', :as => :admin_path
  match 'admin/su'         => 'admin#su'
  match 'admin/save_tag'   => 'admin#save_tag', :via => :post
 
  mount Resque::Server.new, :at => "/resque"
  
  # Main page redirects to index
  root :to => 'landing_page#index'
end