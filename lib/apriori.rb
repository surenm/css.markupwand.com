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

  def candidates(count)
    @rules.combination(count).to_a
  end

  def frequent_itemsets
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

end