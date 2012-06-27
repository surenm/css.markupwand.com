TransformersWeb::Application.routes.draw do
  devise_for :users, :controllers => { :omniauth_callbacks => 'auth' }

  resources :grids
  # grid controllers
  match 'grids/update' => 'grids#generate_markup', :via => :post
  
  # Landing page controller views
  match '/getinvite'       => "landing_page#getinvite"
  
  # Switch user
  match 'su' => 'main#su'
  
  # main controller views
  
  # Dangerous controller route.
  if not Rails.env.production?
    match 'alaguisadude' => 'application#backdoor'
  end

  # design controller routes
  match 'designs'         => 'design#index', :as => :dashboard

  if Constants::store_remote?
    match 'design/new'       => 'design#new'
    match 'design/uploaded'  => 'design#uploaded', :as => :uploaded_callback
  else
    match 'design/new'       => 'design#local_new'
    match 'design/uploaded'  => 'design#local_uploaded', :as => :uploaded_callback
  end
  
  # get, put and edit designs
  match 'design/:id'          => 'design#show'
  match 'design/:id/edit'     => 'design#edit'
  match 'design/:id/preview'  => 'design#preview'
  match 'design/:id/download' => 'design#download'
  match 'design/:id/update'   => 'design#update'
  
  # admin actions to regenerate stuff
  match 'design/:id/reprocess'  => 'design#reprocess'
  match 'design/:id/reparse'    => 'design#reparse'
  match 'design/:id/regenerate' => 'design#regenerate'

  # convinience methods to view logs, dom
  match 'design/:id/view-logs'  => 'design#view_logs'
  match 'design/:id/view-dom'   => 'design#view_dom'
  match 'design/:id/view-json'  => 'design#view_json'
  
  # Proxy method to view generated files
  match ':type/:id/*uri.*ext' => 'design#generated'

  # admin actions for setting up testing
  match 'user/reprocess'  => 'user#reprocess'
  match 'user/reparse'    => 'user#reparse'
  match 'user/regenerate' => 'user#regenerate'
  
    
  # TODO: add admin authentication for Admin URL's 
  mount Resque::Server.new, :at => "/resque"
  
  # Main page redirects to index
  root :to => 'landing_page#index'
end
