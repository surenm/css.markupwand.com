class Hash
  def extract_value(*keys)
    return nil if keys.nil? or keys.empty?

    keys.each_with_index do |key, i|
      if self.nil?
        return nil
      end
      if self[key].class != Array and self[key].class != Hash or i == keys.size-1
        return self[key]
      else
        remaining_keys = keys.slice(i+1, keys.size-i-1)
        return self[key].extract_value(*remaining_keys)
      end
    end
  end
end