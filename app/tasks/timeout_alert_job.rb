class TimeoutAlertJob
  extend Resque::Plugins::History
  @queue = :alerter

  def self.perform(design_id, state_timed_out)
    puts "Alerting +++++++"
    design = Design.find design_id
    Utils::pager_duty_alert "Timedout - #{design_id} - #{state_timed_out}", :user => design.user.email
  end
end