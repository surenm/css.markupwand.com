RailsAdmin.config do |config|
  config.excluded_models = ['DesignGallery', 'InviteRequest', 'SystemFont', 'UserFont']

  config.authorize_with do
    redirect_to main_app.root_path unless warden.user.admin
  end
end