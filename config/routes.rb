TransformersWeb::Application.routes.draw do
  match 'edit' => 'main#edit'
  root :to => 'main#index'
end