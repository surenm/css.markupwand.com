class ParserJob
  extend Resque::Plugins::History
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

      if design.status != Design::STATUS_FAILED
        design.set_status Design::STATUS_PARSED
        Resque.enqueue GeneratorJob, design_id
      end

    rescue Exception => error
      design.set_status Design::STATUS_FAILED
   
      error_description = "Parsing failed for #{design.user.email} on design #{design.safe_name}"
      Utils::pager_duty_alert error_description, :error => error.message, :user => design.user.email
      raise error
    end
  end
end