class DesignGlobals
  # Having design mongo object as reference wont work
  # because, belongs_to references do a Design.find design_id
  # hence it returns a design object with new address space
  # everytime. It means you have to save it. 
  #
  # Having a singleton/global helps because you don't have to 
  # keep writing to mongodb.
  attr_accessor :css_properties_inverted
  @@designglobals = nil

  def self.instance
    if @@designglobals.nil?
      @@designglobals = DesignGlobals.new
    end

    @@designglobals
  end

  def initialize
    @css_properties_inverted = {}
  end

  def self.destroy
    @@designglobals = nil
  end
end