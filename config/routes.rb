TransformersWeb::Application.routes.draw do
  resources :design_files
  match "/designs/*path" => "design_files#serve"
  match '/upload' => "design_files#create"

  match 'edit' => 'main#edit'
  
  root :to => 'main#index'
end
