RAILS_ENV = ENV['RAILS_ENV']
RAILS_ROOT = Dir.pwd

# 16 workers and 1 master in production, 2 workers and 1 master in development
worker_processes (RAILS_ENV == 'production' ? 16 : 2)

# Load rails+github.git into the master before forking workers
# for super-fast worker spawn times
preload_app true

# Restart any workers that haven't responded in 30 seconds
timeout 45

# pid file for the unicorn process
pid '/tmp/unicorn.pid'

# Listen on a Unix data socket
if RAILS_ENV == 'production'
  listen '/tmp/unicorn.sock', :backlog => 2048
else
  listen 3000
end

before_fork do |server, worker|
  ##
  # When sent a USR2, Unicorn will suffix its pidfile with .oldbin and
  # immediately start loading up a new version of itself (loaded with a new
  # version of our app). When this new Unicorn is completely loaded
  # it will begin spawning workers. The first worker spawned will check to
  # see if an .oldbin pidfile exists. If so, this means we've just booted up
  # a new Unicorn and need to tell the old one that it can now die. To do so
  # we send it a QUIT.
  #
  # Using this method we get 0 downtime deploys.

  old_pid = '/tmp/unicorn.pid.oldbin'
  if File.exists?(old_pid) && server.pid != old_pid
    begin
      Process.kill("QUIT", File.read(old_pid).to_i)
    rescue Errno::ENOENT, Errno::ESRCH
      # someone else did our job for us
    end
  end
end