class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Records whose `attribute` contains every word of `query`, in any order and ignoring case, so "jane smith" finds
  # "Smith, Jane". LIKE wildcards in the query match only themselves. Shared by the name searches on Member and Talk.
  # @param attribute [Symbol] a column of this model's table
  # @param query [String]
  # @return [ActiveRecord::Relation]
  def self.matching_every_word(attribute, query)
    query.to_s.split.reduce(all) do |relation, word|
      relation.where(arel_table[attribute].matches("%#{sanitize_sql_like(word)}%", nil, false))
    end
  end
end
