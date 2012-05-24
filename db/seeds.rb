User.all.delete_all
Design.all.delete_all
Grid.all.delete_all
Layer.all.delete_all

# Create an user
[ 
  {
    "email"      => "bot@goyaka.com",
    "first_name" => "Goyaka",
    "last_name"  => "Bot",
    "name"       => "Goyaka Bot",
  }
].each do |user_info|
  user = User.new user_info
  user.save!
end

# TODO: A sample photoshop file

# TODO: A sample photoshop processed file


