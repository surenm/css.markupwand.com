class Design
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated
  include Mongoid::Versioning

  belongs_to :user  
  has_many :grids
  
  field :name, :type => String
end