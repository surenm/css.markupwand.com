class ParserJob
  extend Resque::Plugins::History

  @queue = :parser

  def self.perform(design_id)
    begin
      design = Design.find design_id

      design.set_status Design::STATUS_PARSING

      Store::fetch_from_store design.store_key_prefix
      design_directory = Rails.root.join 'tmp', 'store', design.store_key_prefix
      
      sif_file = File.join design_directory, "#{design.safe_name_prefix}.sif"

      if not File.exists? sif_file
        Log.fatal "SIf file missing. Can't proceed..."
        raise "Missing SIF file"
      end

      Log.info "Found SIF file - #{sif_file}"
      design.sif_file_path = sif_file
      design.save!

      design.group_grids
      return

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