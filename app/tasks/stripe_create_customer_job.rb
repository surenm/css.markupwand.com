class StripeCreateCustomerJob 
  extend Resque::Plugins::History
  @queue = :uploader

  def self.perform(user_email)
    user = User.find_by_email user_email
    customer = Stripe::Customer.create :card => user.stripe_token, :email => user.email, :description => user.plan
    
    user.stripe_customer_id = customer.id
    user.save!
    Resque.enqueue ChatNotifyJob, design.id, "paid-user" 
  end
end