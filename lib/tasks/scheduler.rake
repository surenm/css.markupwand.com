desc "This task checks if a windows machine is stuck"

task :windows_machine_stuck => :environment do
  puts "Checking whether windows machine is stuck"
  design = Design.all.order_by([[:created_at, :asc]]).last

  create_time  = design.created_at
  status       = design.status
  current_time = Time.now
  time_difference = (current_time - create_time)/(3600)

  if (time_difference > 0.5) and status == Design::STATUS_PROCESSING
    puts "Windows machine stuck"
    Utils::pager_duty_alert("Windows machine is stuck. Last item #{design.name} for #{design.user.email} is waiting", {}, Constants::PAGERDUTY_WINDOWS_MACHINE_STUCK)
  else
    puts "Windows machine is fine"
  end

end
