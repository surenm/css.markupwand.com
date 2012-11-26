class GroupingBoxJob
  extend Resque::Plugins::History
  
  @queue = :worker

  def self.perform(design_id)
    design = Design.find design_id
    design.create_grouping_boxes

    Resque.enqueue GridJob, design_id
  end
end