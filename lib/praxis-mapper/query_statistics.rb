module Praxis::Mapper

  class QueryStatistics

    def initialize(queries_by_model)
      @queries_by_model = queries_by_model
    end

    # sums up statistics across all queries, indexed by model
    def sum_totals_by_model
      @sum_totals_by_model ||= begin
        totals = Hash.new { |hash, key| hash[key] = Hash.new(0) }

        @queries_by_model.each do |model, queries|
          totals[model][:query_count] = queries.length
          queries.each do |query|
            query.statistics.each do |stat, value|
              totals[model][stat] += value
            end
          end

          totals[model][:datastore_interaction_time] = totals[model][:datastore_interaction_time]
        end

        totals
      end
    end

    # sums up statistics across all models and queries
    def sum_totals
      @sum_totals ||= begin
        totals = Hash.new(0)

        sum_totals_by_model.each do |_, model_totals|
          model_totals.each do |stat, value|
            totals[stat] += value
          end
        end

        totals
      end
    end

  end

end
