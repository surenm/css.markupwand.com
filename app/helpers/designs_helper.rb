module DesignsHelper
  def self.short_form(word, num_chars)
    if word.size <= num_chars
      return word
    else
      word.slice(0, num_chars-4) + "..."
    end
  end

  def self.status_display_name(status)
    case status
      when Design::STATUS_COMPLETED
        return :completed
      when Design::STATUS_FAILED
        return :failed
      else
        return :processing
    end
  end
end
