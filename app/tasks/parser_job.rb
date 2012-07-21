class ParserJob
  @queue = :parser

  def self.perform(readable_design_id)
    begin
      design_id = readable_design_id.split('-').last
      design = Design.find design_id

      design.set_status Design::STATUS_PARSING

      Store::fetch_from_store design.store_processed_key
      design_processed_directory = Rails.root.join 'tmp', 'store', design.store_processed_key
      Log.info "Design processed directory : #{design_processed_directory} "

      Dir["#{design_processed_directory}/*.psd.json"].each do |processed_file|
        Log.info "Found processed file - #{processed_file}"
        design.processed_file_path = processed_file
        design.save!
        break
      end

      design.parse
      design.set_status Design::STATUS_PARSED

      # Generate markup for editing and publishing
      Resque.enqueue GeneratorJob, design_id
    rescue Exception => error
      error_description = "Parsing failed for #{design.user.email} on design #{design.safe_name}"
      Utils::pager_duty_alert error_description, :error => error, :user => design.user.email
      design.set_status Design::STATUS_FAILED
      raise error
    end
  end
end