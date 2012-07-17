class HtmlWriterJob
  @queue = :html_writer

  def self.perform(design_id)
    begin
      design = Design.find design_id

      # Set design back to generating
      design.set_status Design::STATUS_REGENERATING

      # Generate markup once in editable mode once
      design.write_html_and_css

      # mark editing complete
      design.set_status Design::STATUS_COMPLETED
    rescue Exception => error
      Utils::pager_duty_alert("391c2640ab64012f2bf422000afc419f", File.basename(design.processed_file_path), error, design.user.email) if Rails.env.production?
      design.set_status Design::STATUS_FAILED
      raise error
    end
  end
end