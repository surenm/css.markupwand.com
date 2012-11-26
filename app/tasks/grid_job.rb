class GridJob
  extend Resque::Plugins::History

  @queue = :worker

  def self.perform(design_id)
    design = Design.find design_id
    design.create_grids
  end
end