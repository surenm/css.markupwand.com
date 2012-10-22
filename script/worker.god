require "pp"


class EnvironmentVariables
  GOD_FILE   = __FILE__
  RAILS_ROOT = File.expand_path '..', File.dirname(GOD_FILE)
  ENV_FILE   = File.join RAILS_ROOT, ".env"
  
  def self.get_from_env_file
    env_lines = IO.readlines ENV_FILE

    env_vars = Hash.new
    env_vars["QUEUE"] = "uploader,extractor,parser,generator,misc_tasks"

    for line in env_lines
      tokens = line.split "="
      key   = tokens[0]
      value = tokens[1..-1].join("=").rstrip
      
      env_vars[key] = value
    end
  
    return env_vars
  end

  def self.get_from_heroku_config
  end
  
  def self.rails_root_directory
    return RAILS_ROOT
  end
end


NUM_WORKERS = 2

NUM_WORKERS.times do |num|
  God.watch do |w|
    w.env = EnvironmentVariables.get_from_env_file

    if w.env["RAILS_ENV"] == :production
      w.uid = 'ubuntu'
      w.gid = 'ubuntu'
    end

    w.log      = "/tmp/worker.log"
    w.dir      = EnvironmentVariables.rails_root_directory
    w.name     = "worker-#{num}"
    w.group    = 'workers'
    w.interval = 30.seconds
    
    w.start    ="rake -f #{EnvironmentVariables.rails_root_directory}/Rakefile environment resque:work"

    # restart if memory gets too high
    w.transition(:up, :restart) do |on|
      on.condition(:memory_usage) do |c|
        c.above = 1500.megabytes
        c.times = 2
      end
    end

    # determine the state on startup
    w.transition(:init, { true => :up, false => :start }) do |on|
      on.condition(:process_running) do |c|
        c.running = true
      end
    end

    # determine when process has finished starting
    w.transition([:start, :restart], :up) do |on|
      on.condition(:process_running) do |c|
        c.running = true
        c.interval = 5.seconds
      end

      # failsafe
      on.condition(:tries) do |c|
        c.times = 5
        c.transition = :start
        c.interval = 5.seconds
      end
    end

    # start if process is not running
    w.transition(:up, :start) do |on|
      on.condition(:process_running) do |c|
        c.running = false
      end
    end
  end
end
