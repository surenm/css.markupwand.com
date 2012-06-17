TransformersWeb::Application.routes.draw do
  devise_for :users, :controllers => { :omniauth_callbacks => 'auth' }

  resources :grids
  # grid controllers
  match 'grids/update' => 'grids#generate_markup', :via => :post
  
  # Landing page controller views
  match '/getinvite'       => "landing_page#getinvite"
  
  # main controller views
  
  # Dangerous controller route.
  if not Rails.env.production?
    match 'alaguisadude' => 'application#backdoor'
  end

  # design controller routes
  match 'designs'         => 'design#index'

  match 'design/new'       => 'design#new'
  match 'design/uploaded'  => 'design#uploaded', :as => :uploaded_callback

  # photoshop machines will ping back on this url
  match 'design/processed' => 'design#processed', :as => :processed_callback

  # get, put and edit designs
  match 'design/:id'          => 'design#show'
  match 'design/:id/update'   => 'design#update', :via => :post
  match 'design/:id/edit'     => 'design#edit'
  match 'design/:id/preview'  => 'design#preview'
  match 'design/:id/download' => 'design#download'

  
  # Proxy method to view generated files
  match ':type/:design/*uri.*ext' => 'design#generated'
  
  # TODO: add admin authentication for Admin URL's 
  mount Resque::Server.new, :at => "/resque"
  
  # Main page redirects to index
  root :to => 'landing_page#index'
end
