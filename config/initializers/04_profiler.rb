module Profiler
  # Enable profiling if environment variable is set
  def Profiler::profiling_enabled?
    if ENV['PROFILE'] == "true"
      return true
    else 
      return false
    end
  end
  
  def Profiler::start
    if Profiler::profiling_enabled? and not RubyProf.running?
      RubyProf.start
    end
  end
  
  def Profiler::stop
    if RubyProf.running?
      result       = RubyProf.stop
      printer      = RubyProf::GraphHtmlPrinter.new result
      profile_file = File.new Rails.root.join("tmp", "profile-#{Time.now}.html"), 'w+'
      printer.print profile_file, :min_percent => 10
      profile_file.close
    end
  end
end