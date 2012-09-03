class ParserJob
  extend Resque::Plugins::History

  @queue = :parser

  def self.perform(readable_design_id)
    begin
      design_id = readable_design_id.split('-').last
      design = Design.find design_id

      design.set_status Design::STATUS_PARSING

      Store::fetch_from_store design.store_extracted_key
      design_extracted_key = Rails.root.join 'tmp', 'store', design.store_extracted_key
      
      extracted_file = File.join design_extracted_key, "#{design.safe_name_prefix}.json"

      if not File.exists? extracted_file
        Log.fatal "Extracted design file missing. Can't parse..."
        raise "Missing extracted design file"
      end

      Log.info "Found extracted file - #{extracted_file}"
      design.processed_file_path = extracted_file
      design.save!

      #Create from SIF files
      design.populate_sif

      design.group_grids

      Store::delete_from_store design.store_generated_key
      Store::delete_from_store design.store_published_key

      design.set_status Design::STATUS_GENERATING
      design.save!

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