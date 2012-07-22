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
      error_description = "HTML Writer failed for #{design.user.email} on design #{design.safe_name}"
      Utils::pager_duty_alert error_description, :error => error, :user => design.user.email
      
      design.set_status Design::STATUS_FAILED
      raise error
    end
  end
end