class HtmlRegenerateJob
  @queue = :generator

  def self.perform(design_id)
    begin
      design = Design.find design_id

      # Set design back to generating
      design.set_status Design::STATUS_GENERATING

      # Generate markup once in editable mode once
      design.write_html_and_css

      # mark editing complete
      design.set_status Design::STATUS_COMPLETED

      if Rails.env.production?
        ApplicationHelper.post_simple_message("#{design.user.name} <#{design.user.email}>", "#{design.name} generated", "Your HTML & CSS has been regenerated, click http://www.markupwand.com/design/#{design.safe_name}/preview to download")
      end
    rescue Exception => error
      Utils::pager_duty_alert("391c2640ab64012f2bf422000afc419f", File.basename(design.processed_file_path), error, design.user.email) if Rails.env.production?
      design.set_status Design::STATUS_FAILED
      raise error
    end
  end
end