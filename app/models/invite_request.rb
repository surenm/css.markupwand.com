class InviteRequest
  include Mongoid::Document
  include Mongoid::Versioning
  accepts_nested_attributes_for :versions
  
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated

  InviteRequest::APPROVED = :approved
  InviteRequest::REQUESTED = :requested

  field :email, :type => String
  field :status, :type => Symbol, :default => InviteRequest::REQUESTED
  field :requestor_ip, :type => String
end