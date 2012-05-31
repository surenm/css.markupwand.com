TransformersWeb::Application.routes.draw do
  devise_for :users, :controllers => { :omniauth_callbacks => 'auth' }

  resources :design_files, :grids
  
  match '/designs/*path'   => "design_files#serve"
  match 'next_unprocessed' => "design_files#next_unprocessed"
  match '/upload'          => "design_files#create"
  match '/getinvite'       => "landing_page#getinvite"
  
  match '/beta'            => "main#index"
  
  # main controller views
  match 'edit'    => 'main#edit'
  match 'designs' => 'main#list'
  
  # Dangerous controller route. 
  # TODO: allow only in development??
  match 'alaguisadude' => 'application#backdoor'

  
  # grid controllers
  match 'grids/update' => 'grids#generate_markup', :via => :post
  
  # Proxy method to view generated files
  match 'generated/*uri.*ext' => 'main#generated'
  
  # Main page redirects to index
  root :to => 'landing_page#index'
end
