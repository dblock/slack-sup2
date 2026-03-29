module SlackSup
  module Models
    module Mixins
      module PeriodStats
        extend ActiveSupport::Concern

        def period_since
          case period
          when 'monthly' then 1.year.ago.beginning_of_month
          when 'quarterly' then 3.years.ago.beginning_of_quarter
          end
        end

        def period_label(id)
          case period
          when 'yearly'
            id['year'].to_s
          when 'monthly'
            "#{Date::MONTHNAMES[id['month']]} #{id['year']}"
          when 'quarterly'
            "Q#{id['quarter'].to_i} #{id['year']}"
          end
        end

        def period_to_s_lines
          return [] unless period && period_data&.any?

          lines = []
          period_data.each do |entry|
            sups = entry['sups_count']
            rounds = entry['rounds_count']
            positive = entry['positive_outcomes_count']
            reported = entry['reported_outcomes_count']
            lines << "#{period_label(entry['_id'])}: Facilitated #{pluralize(sups, 'S\'Up')} in #{pluralize(rounds, 'round')} " \
                     "with #{positive * 100 / sups}% positive outcomes from #{reported * 100 / sups}% outcomes reported."
          end
          lines
        end
      end
    end
  end
end
