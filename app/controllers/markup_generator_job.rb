class MarkupGeneratorJob
  @queue = :generator
  
  def self.perform(design_id)
    design = Design.find design_id
    Log.info design
  end
end