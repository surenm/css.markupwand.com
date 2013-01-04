class ImagesCompletedJob
  extend Resque::Plugins::History
  @queue = :worker

  def self.perform(design_id)
    design = Design.fetch design_id
    design.photoshop_status = Design::STATUS_PROCESSING_DONE
    design.save!
  end
end