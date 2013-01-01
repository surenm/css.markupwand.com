class ImagesCompletedJob
  @queue = :worker

  def self.perform(design_id)
    design = Design.fetch design_id
  end
end