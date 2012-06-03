TransformersWeb::Application.routes.draw do
  devise_for :users, :controllers => { :omniauth_callbacks => 'auth' }

  resources :grids
  
  #match '/designs/*path'   => "design_files#serve"
  #match 'next_unprocessed' => "design_files#next_unprocessed"
  #match '/upload'          => "design_files#create"
  match '/getinvite'       => "landing_page#getinvite"
  
  # main controller views
  match 'edit'    => 'main#edit'

  # Dangerous controller route. 
  # TODO: allow only in development??
  match 'alaguisadude' => 'application#backdoor'

  # design controller routes
  match 'designs' => 'design#index'
  match 'designs/new' => 'design#new'
  match 'designs/uploaded' => 'design#upload', :as => :upload_callback
  match 'design/*id' => 'design#show', :via => :get
  match 'design/*id' => 'design#update', :via => :put
  
  # grid controllers
  match 'grids/update' => 'grids#generate_markup', :via => :post
  

  # Proxy method to view generated files
  match 'generated/:design/*uri.*ext' => 'main#generated'
  
  # Main page redirects to index
  root :to => 'landing_page#index'
end
