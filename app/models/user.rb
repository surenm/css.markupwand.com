class User
  include Mongoid::Document
  include Mongoid::Versioning
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated

  devise :database_authenticatable, :registerable, :validatable, :rememberable, :trackable, :omniauthable, :timeoutable, :recoverable #, :confirmable

  User::PLAN_FREE = :free
  User::PLAN_SEDAN = :sedan
  User::PLAN_SUV = :suv

  ## Rememberable
  field :remember_created_at, :type => Time

  ## Trackable
  field :sign_in_count,         :type => Integer, :default => 0
  field :current_sign_in_at,    :type => Time
  field :last_sign_in_at,       :type => Time
  field :current_sign_in_ip,    :type => String
  field :last_sign_in_ip,       :type => String
  field :confirmed_at,          :type => Time
  field :confirmation_sent_at,  :type => Time
  field :confirmation_token,    :type => String
  field :reset_password_token,  :type => String
  field :reset_password_sent_at, :type => Time

  field :email, :type => String
  field :name, :type => String
  field :encrypted_password, :type => String
  field :first_name, :type => String, :default => nil
  field :last_name, :type => String, :default => nil
  field :admin, :type => Boolean, :default => false

  field :plan, :type => Symbol, :default => User::PLAN_FREE
  field :stripe_token, :type => String, :default => nil

  field :enabled, :type => Boolean, :default => !Constants::invite_gated?

  index({email: 1}, {unique: true})
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
    User.where(:email => email).exists?
  end

  def self.find_or_create_admin_user(access_token)
    data = access_token.info
    email_domain = User.get_email_domain data['email']
    
    if email_domain != "markupwand.com"
      raise "Forbidden. You are not an admin."
    end
    
    if user_exists? data["email"]
      user = User.find_by_email data["email"]
      user.update_attributes! :admin => true
    else
      user = User.create! :email => data["email"], :name => data["name"], :first_name => data["first_name"], :last_name => data["last_name"], :admin => true, :password => Devise.friendly_token[0,20]
    end
    
    return user    
  end

  def self.find_or_create_google_user(access_token)
    data = access_token.info
    email_domain = User.get_email_domain data['email']
    
    if email_domain == "markupwand.com"
      return User.find_or_create_admin_user(access_token)
    end

    if user_exists? data["email"]
      user = User.find_by_email data["email"]
    else
      subject = "New User #{data['name']} (#{data['email']}) signed up"

      user = User.create! :email => data["email"], :name => data["name"], :first_name => data["first_name"], :last_name => data["last_name"], :password => Devise.friendly_token[0,20]
    end

    return user
  end

  def get_display_name
    if not self.first_name.nil?
      return self.first_name
    elsif not self.name.nil?
      return self.name
    else
      return self.email
    end
  end
end
