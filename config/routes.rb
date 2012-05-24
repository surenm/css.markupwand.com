TransformersWeb::Application.routes.draw do
  devise_for :users, :controllers => { :omniauth_callbacks => 'auth' }

  resources :design_files
  match '/designs/*path'      => "design_files#serve"
  match 'next_unprocessed'    => "design_files#next_unprocessed"
  match '/upload'             => "design_files#create"
  
  # Annotator interface
  match 'edit'                => 'main#edit'
  
  # Proxy method to view generated files
  match 'generated/*uri.*ext' => 'main#generated'
  
  # Main page redirects to index
  root :to => 'main#index'
end
