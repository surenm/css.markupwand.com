TransformersWeb::Application.routes.draw do
  resources :design_files
  match "/designs/*path" => "design_files#serve"
  match 'next_unprocessed' => "design_files#next_unprocessed"
  match '/upload' => "design_files#create"
  match 'edit' => 'main#edit'
  
  match 'generated/*uri.*ext' => 'main#generated'
  
  root :to => 'main#index'
end
