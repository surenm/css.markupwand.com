class GridJob
  extend Resque::Plugins::History

  @queue = :worker

  def self.perform(design_id)
    design = Design.find design_id
    design_folder  = Store.fetch_from_store design.store_key_prefix
    design.create_grids
    Resque.enqueue HtmlJob, design_id
  end
end