class MarkupRegeneratorJob
  @queue = :regenerator
  
  def self.perform(design_id, publish = false)
    design = Design.find design_id
    design.set_status Design::STATUS_REGENERATING
    Store::fetch_from_store design.store_processed_key
    design.generate_markup !publish
    design.set_status Design::STATUS_COMPLETED
  end
end