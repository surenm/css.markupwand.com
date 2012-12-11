class ConversionJob
  extend Resque::Plugins::History
  @queue = :worker

  def self.perform(design_id)
    design = Design.find design_id
    ExtractorJob.perform design_id
    GroupingBoxJob.perform design_id
    GridJob.perform design_id
    HtmlJob.peform design_id
  end
end
