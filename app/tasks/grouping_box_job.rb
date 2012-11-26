class GroupingBoxJob
  extend Resque::Plugins::History
  
  @queue = :grouping_box

  def self.perform(design_id)
    design = Design.find design_id
    design.create_grouping_boxes

    Resque.enqueue GridJob, design_id
  end
end