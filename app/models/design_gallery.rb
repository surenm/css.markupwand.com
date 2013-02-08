class DesignGallery
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include Mongoid::Timestamps::Updated
  include Mongoid::Versioning
  accepts_nested_attributes_for :versions
  
  has_many :designs

  field :votes, :type => Hash, :default => {}

  # Inefficient design when we have 1000s of users, and 100s of items in gallery.
  # But good enough for now - Less complicated.
  # FIXME: Revisit before July 20th(TC plan)
  field :user_design_votes_map, :type => Hash, :default => {}

  private
  def get_design_vote_map(design_id)
    design_vote_map = self.votes[design_id]
    if design_vote_map.nil?
      design_vote_map = {}
      design_vote_map = {"upvotes" => 0, "downvotes" => 0}
    end
    return design_vote_map
  end

  def get_user_vote_map(user_id)
    user_vote_map = self.user_design_votes_map[user_id]
    if user_vote_map.nil?
      user_vote_map = {"upvoted_designs" => [], "downvoted_designs" => []}
    end
    return user_vote_map
  end

  public
  # For now, there can be only one gallery. No user specific galleries yet.
  # So, making it a singleton. Change this when there is need to have more galleries.
  def self.instance
    # The one time activity of creating gallery shouldn't be handled here.
    # So counting on rake db:seed to take care of inserting the one and only gallery.
    return self.first
  end

  def upvote(design_id, user)
    design_vote_map = get_design_vote_map(design_id)
    user_design_map = get_user_vote_map(user.id.to_s)

    design_vote_map["upvotes"] += 1
    self.votes[design_id] = design_vote_map

    #Add to upvoted designs, and remove from downvoted designs if previously downvoted.
    user_design_map["upvoted_designs"].push design_id
    user_design_map["upvoted_designs"].uniq!
    user_design_map["downvoted_designs"].delete design_id
    self.user_design_votes_map[user.id.to_s] = user_design_map

    self.save!
  end

  def downvote(design_id, user)
    design_vote_map = get_design_vote_map(design_id)
    user_design_map = get_user_vote_map(user.id.to_s)

    design_vote_map["downvotes"] += 1
    self.votes[design_id] = design_vote_map

    #Add to downvoted designs, and remove from upvoted designs if previously upvoted.
    user_design_map["downvoted_designs"].push design_id
    user_design_map["downvoted_designs"].uniq!
    user_design_map["upvoted_designs"].delete design_id
    self.user_design_votes_map[user.id.to_s] = user_design_map

    self.save!
  end
end