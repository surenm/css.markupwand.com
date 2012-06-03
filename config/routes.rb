TransformersWeb::Application.routes.draw do
  devise_for :users, :controllers => { :omniauth_callbacks => 'auth' }

  resources :design_files, :grids
  
  #match '/designs/*path'   => "design_files#serve"
  #match 'next_unprocessed' => "design_files#next_unprocessed"
  #match '/upload'          => "design_files#create"
  match '/getinvite'       => "landing_page#getinvite"
  
  match '/beta'            => "main#index"
  
  # main controller views
  match 'edit'    => 'main#edit'

  
  # Dangerous controller route. 
  # TODO: allow only in development??
  match 'alaguisadude' => 'application#backdoor'

  # design controller routes
  match 'designs' => 'design#index'
  match 'designs/upload' => 'design#upload', :via => :post
  match 'design/*id' => 'design#show', :via => :get
  match 'design/*id' => 'design#update', :via => :put
  
  # grid controllers
  match 'grids/update' => 'grids#generate_markup', :via => :post
  

  # Proxy method to view generated files
  match 'generated/:design/*uri.*ext' => 'main#generated'
  
  # Main page redirects to index
  root :to => 'landing_page#index'
end
