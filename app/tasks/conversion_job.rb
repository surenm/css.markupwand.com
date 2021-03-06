class ConversionJob
  extend Resque::Plugins::History
  @queue = :worker

  def self.perform(design_id)
    design = Design.find design_id

    # fetch files once
    design_folder  = Store.fetch_from_store design.store_key_prefix    

    # Run psdjs job alone
    PsdjsJob.perform design_id

    # create grouping box        
    design.set_status Design::STATUS_GROUPING
    design.create_grouping_boxes

    # create grids
    design.set_status Design::STATUS_GRIDS
    design.create_grids

    # Generate markup
    design.set_status Design::STATUS_MARKUP
    design.generate_markup

    # Completed
    design.set_status Design::STATUS_COMPLETED
  end
end