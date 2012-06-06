TransformersWeb::Application.routes.draw do
  devise_for :users, :controllers => { :omniauth_callbacks => 'auth' }

  resources :grids
  # grid controllers
  match 'grids/update' => 'grids#generate_markup', :via => :post
  
  # Landing page controller views
  match '/getinvite'       => "landing_page#getinvite"
  
  # main controller views
  # Proxy method to view generated files
  match 'generated/:design/*uri.*ext' => 'main#generated'
  
  # Dangerous controller route.
  if not Rails.env.production?
    match 'alaguisadude' => 'application#backdoor'
  end

  # design controller routes
  match 'designs'         => 'design#index'

  if Constants::store_remote?
    match 'design/new'      => 'design#new'
    match 'design/uploaded' => 'design#uploaded', :as => :upload_callback
  else
    match 'design/new'      => 'design#local_new'
    match 'design/uploaded' => 'design#local_uploaded', :as => :upload_callback
  end
  
  match 'design/:id'      => 'design#show', :via => :get
  match 'design/:id'      => 'design#update', :via => :put
  match 'design/:id/edit' => 'design#edit'
  

  # Main page redirects to index
  root :to => 'landing_page#index'
end
