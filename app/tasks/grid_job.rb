class GridJob
  extend Resque::Plugins::History

  @queue = :worker

  def self.perform(design_id)
    design = Design.find design_id
    design.set_status Design::STATUS_GRIDS
    design.create_grids

    Resque.enqueue HtmlJob, design_id
  end
end