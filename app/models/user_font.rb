class UserFont
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated

  field :fontname, :type => String
  field :filename, :type => String
  field :type, 	   :type => String

  belongs_to :user

  def user_fonts_dir
    File.join self.user.email, "fonts"
  end

  def file_path
    user_fonts_dir + "/" + self.filename
  end

  def save_from_url(source_url)
  	Store::write_from_url file_path, source_url
  end
end