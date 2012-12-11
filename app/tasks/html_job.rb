class HtmlJob
  extend Resque::Plugins::History
  @queue = :worker

  def self.perform(design_id)
    design = Design.find design_id
    design.set_status Design::STATUS_MARKUP
    design.generate_markup
    design.set_status Design::STATUS_COMPLETED
  end
end