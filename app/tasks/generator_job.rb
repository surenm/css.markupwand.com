class GeneratorJob
  @queue = :generator

  def self.perform(design_id)
    begin
      design = Design.find design_id

      # Set design back to generating
      design.set_status Design::STATUS_GENERATING

      # Fetch the processed files once again
      Store::fetch_from_store design.store_processed_key

      # delete the generated and published folder
      Store::delete_from_store design.store_generated_key
      Store::delete_from_store design.store_published_key

      # Generate markup once in editable mode once
      design.generate_markup :enable_data_attributes => true

      # mark editing complete
      design.set_status Design::STATUS_COMPLETED
      
      if not design.user.admin
        ApplicationHelper.post_simple_message("#{design.user.name} <#{design.user.email}>", "#{design.name} generated", "Your HTML & CSS has been generated, click http://www.markupwand.com/design/#{design.safe_name}/preview to download")
      end
    rescue Exception => error
      error_description = "HTML generation failed for #{design.user.email} on design #{design.safe_name}"
      Utils::pager_duty_alert error_description, :error => error, :user => design.user.email
      design.set_status Design::STATUS_FAILED
      raise error
    end
  end
end