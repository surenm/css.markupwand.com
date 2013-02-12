require 'digest/md5'

class User
  include Mongoid::Document
  include Mongoid::Versioning
  accepts_nested_attributes_for :versions
  
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated

  devise :database_authenticatable, :registerable, :validatable, :rememberable, :trackable, :omniauthable, :timeoutable, :recoverable #, :confirmable

  User::PLAN_FREE = :free
  User::PLAN_REGULAR = :regular
  User::PLAN_PLUS = :plus

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
  field :stripe_customer_id, :type => String, :default => nil

  field :enabled, :type => Boolean, :default => true

  index({email: 1}, {unique: true})
  validates_presence_of :name, :email
  
  has_many :designs
  has_many :user_fonts  

  rails_admin do
    list do
      field :name
      field :email
      field :plan
      field :last_sign_in_at
      field :sign_in_count
      field :designs do
        label "Design count"
        pretty_value do
          value.length.to_s
        end
      end
    end
  end

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

  def attribute_data
    year = Time.now.year
    month = Time.now.month
    this_month_designs = self.designs.where :created_at.gte => "#{year}-#{month}-1"
    {
      :name => self.get_display_name,
      :plan => self.plan,
      :gravatar => self.get_gravtar_image_url,
      :designs_count => this_month_designs.count,
    }
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

  def get_gravtar_image_url
    email_address = self.email.downcase
    hash = Digest::MD5.hexdigest(email_address)
    return "https://www.gravatar.com/avatar/#{hash}"
  end

  def create_sample_designs
    sample_designs = ["sample.psd"]

    sample_designs.each do |design_name|
      design = Design.new :name => design_name
      design.user = self
      design.is_sample_design = true
      design.psd_file_path = File.join design.store_key_prefix, design.safe_name_prefix
      design.save!

      Resque.enqueue SampleJob, design.id
    end
  end
end
