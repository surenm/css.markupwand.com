class MarkupGeneratorJob
  @queue = :generator
  
  def self.perform(design_id)
    design = Design.find design_id

    # Set design back to generating
    design.set_status Design::STATUS_GENERATING
    
    # Fetch the processed files once again
    Store::fetch_from_store design.store_processed_key

    # Generate markup once in publishable mode once
    #design.generate_markup :enable_data_attributes => false
    
    # Generate markup once in editable mode once
    design.generate_markup :enable_data_attributes => true

    # mark editing complete
    design.set_status Design::STATUS_COMPLETED

    if Rails.env.production?
      ApplicationHelper.post_simple_message("#{design.user.name} <#{design.user.email}>", "#{design.name} generated", "Click -> http://www.markupwand.com/design/#{design.safe_name}/edit")
    end
  end
end