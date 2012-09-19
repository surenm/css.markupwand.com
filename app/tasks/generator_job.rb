class GeneratorJob
  extend Resque::Plugins::History

  @queue = :generator

  def self.perform(design_id)
    begin
      design = Design.find design_id

      design.set_status Design::STATUS_GENERATING
      design.save!

      Store::fetch_from_store design.store_key_prefix
      design_directory = Rails.root.join 'tmp', 'store', design.store_key_prefix
      
      sif_file_path = Rails.root.join 'tmp', 'store', design.get_sif_file_path

      if not File.exists? sif_file_path
        Log.fatal "SIf file missing. Can't proceed..."
        raise "Missing SIF file"
      end

      Store::delete_from_store design.store_generated_key
      Store::delete_from_store design.store_published_key

      design.generate_markup :enable_data_attributes => true

      if design.status != Design::STATUS_FAILED
        design.set_status Design::STATUS_COMPLETED
      end

    rescue Exception => error
      design.set_status Design::STATUS_FAILED
   
      error_description = "Parsing failed for #{design.user.email} on design #{design.safe_name}"
      Utils::pager_duty_alert error_description, :error => error.message, :user => design.user.email
      raise error
    end
  end
end