class NilClass
  def [](*args)
    Log.error "Trying to access nil object in #{Kernel.caller}"
    return nil
  end

  def method_missing(method_name, *args, &block)
    Log.error "Unknown method '#{method_name}' for nil object in #{Kernel.caller}"
    return nil
  end
end