class User
  include Mongoid::Document
  include Mongoid::Versioning
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated

  devise :rememberable, :trackable, :omniauthable, :timeoutable

  ## Rememberable
  field :remember_created_at, :type => Time

  ## Trackable
  field :sign_in_count,      :type => Integer, :default => 0
  field :current_sign_in_at, :type => Time
  field :last_sign_in_at,    :type => Time
  field :current_sign_in_ip, :type => String
  field :last_sign_in_ip,    :type => String

  field :email, :type => String
  field :name, :type => String
  field :first_name, :type => String, :default => nil
  field :last_name, :type => String, :default => nil
  field :admin, :type => Boolean, :default => false

  field :enabled, :type => Boolean, :default => !Constants::invite_gated?

  index :email, :unique => true
  validates_presence_of :name, :email
  
  has_many :designs
  has_many :user_fonts  

  def self.get_email_domain(email_address)
    return email_address.split('@').last
  end

  def self.find_by_email(email)
    user = User.where(:email => email).first
  end

  def self.user_exists?(email)
    User.exists? :conditions => {:email => email}
  end

  def self.find_or_create_admin_user(access_token)
    data = access_token.info
    email_domain = User.get_email_domain data['email']
    
    if email_domain != "goyaka.com"
      raise "Forbidden. You are not an admin."
    end
    
    if user_exists? data["email"]
      user = User.find_by_email data["email"]
      user.update_attributes! :admin => true
    else
      user = User.create! :email => data["email"], :name => data["name"], :first_name => data["first_name"], :last_name => data["last_name"], :admin => true
    end
    
    return user    
  end

  def self.find_or_create_google_user(access_token)
    data = access_token.info
    email_domain = User.get_email_domain data['email']
    
    if email_domain == "goyaka.com"
      return User.find_or_create_admin_user(access_token)
    end

    if user_exists? data["email"]
      user = User.find_by_email data["email"]
    else
      subject = "New User #{data['name']} (#{data['email']}) signed up"
      ApplicationHelper.post_simple_message "alerts+newuser@markupwand.com", subject, ""

      user = User.create! :email => data["email"], :name => data["name"], :first_name => data["first_name"], :last_name => data["last_name"]
    end

    return user
  end
end
