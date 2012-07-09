class Apriori
  #
  # A data hash is a hash with array
  # 
  # data_hash example
  #
  # data_hash = {
  #   'A' => [1, 2, 3, 4],
  #   'B' => [4, 5, 2, 6],
  #   'C' => [2]
  # }
  #
  # min_support = 1 (atleast there should be one property i.e C is discarded)
  # 
  attr_accessor :data_hash, :minsup, :itemsets

  def initialize(data_hash, minsup)
    @minsup    = minsup

    @data_hash = prune_minsup(data_hash)

    @rules     = data_hash.keys.sort
    @nodes     = data_hash.values.flatten.uniq.sort 
    @associations = []
  end 

  # Remove all the items less than minimum support
  def prune_minsup(item_table)
    item_table.each do |rule, nodes|
      item_table.delete rule if nodes.length < @minsup
    end
  end

  def first_pass
    keys = @rules.clone.zip
    first_association = {}
    keys.each do |key|
      first_association[key] = @data_hash[key.first]
    end
    @associations[1] = prune_minsup first_association
  end

  def candidates(rule_count)
    prev_association_rules = @associations[rule_count-1].keys.flatten.uniq
    prev_association_rules.combination(rule_count).to_a
  end

  def calculate_frequent_itemsets
    first_pass
    rule_count = 2

    while not @associations[rule_count - 1].empty?
      rule_candidates = candidates(rule_count)
      next_rule_association = {}
      rule_candidates.each do |rules|
        prev_rule_subset = rules.slice(0, rules.length - 1)
        extra_rule       = [rules[rules.length - 1]]

        if @associations[rule_count - 1].has_key? prev_rule_subset
          items_in_rule =  @associations[1][extra_rule] & @associations[rule_count - 1][prev_rule_subset]
          if not items_in_rule.empty?
            next_rule_association[rules] = items_in_rule
          end 
        end
        # TODO Prune later.
      end

      @associations[rule_count] = prune_minsup next_rule_association
      rule_count += 1
    end

    @associations
  end

  def get_association_item_count(association)
    total = 0
    if association.is_a? Hash
      association.each do |key, value|
        total = total + value.length
      end
    end

    total
  end

  def max_association_match
    if @associations.empty?
      return nil
    end

    max_association_count = 0
    max_association_index = -1

    @associations.each_with_index do |association, index|
      association_item_count = get_association_item_count(association)
      max_association_index = index if association_item_count > max_association_count
      max_association_count = association_item_count if association_item_count > max_association_count
    end

    @associations[max_association_index]
  end

  def get_array_distance(array1, array2)
    [(array1 - array2).length, (array2 - array1).length].min
  end

  def get_rule_distance(rule1, rule2)
    key_distance = get_array_distance(rule1.keys.first, rule2.keys.first)
    node_distance = get_array_distance(rule1.values.first, rule2.values.first)
    return (key_distance + node_distance)
  end


  def subset_rule_exists_in_association(association, subset_rule)
    subset_exists = false
    association.each do |rule, nodes|
      if not (subset_rule - rule).empty?
        subset_exists = true
        break
      end
    end

    subset_exists
  end

  def get_class_groups(association)
    new_association = {}
    association.each do |primary_rule, primary_nodes|
      if not subset_rule_exists_in_association(new_association, primary_rule)
        association.each do |secondary_rule, secondary_nodes|
          if primary_rule != secondary_rule
            rule_distance = get_rule_distance({primary_rule => primary_nodes}, {secondary_rule => secondary_nodes})

            # Not sure if this should be 3 or calculated based on data.
            if rule_distance < 3
              new_rule = (primary_rule + secondary_rule).sort.uniq
              new_value = (primary_nodes + secondary_nodes).sort.uniq
              new_association.update { new_rule => new_value }

              Log.info "------------------------"
              Log.info "SIMILAR #{rule_distance}"
              Log.info "#{primary_rule.to_s}"
              Log.info "#{secondary_rule.to_s}"
            end
          end
        end
      end
    end
  end

end