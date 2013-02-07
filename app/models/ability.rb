class Ability
  include CanCan::Ability

  Ability::PLAN_LIMITS = {
    User::PLAN_FREE => 2,
    User::PLAN_REGULAR => 15,
    User::PLAN_PLUS => -1,
  }

  def initialize(user)
    can :create, Design do |design|
        if user.plan == User::PLAN_PLUS
            true
        else
            year = Time.now.year
            month = Time.now.month
            this_month_designs = user.designs.where :created_at.gte => "#{year}-#{month}-1"
            this_month_designs.count < Ability::PLAN_LIMITS[user.plan]
        end
    end
 end
end
