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

        def period_key(id)
          case period
          when 'yearly' then id['year']
          when 'monthly' then [id['year'], id['month']]
          when 'quarterly' then [id['year'], id['quarter'].to_i]
          end
        end

        def all_period_ids
          return [] if period_data.nil? || period_data.empty?

          ids = period_data.map { |e| e['_id'] }

          case period
          when 'yearly'
            years = ids.map { |id| id['year'] }
            (years.min..years.max).map { |y| { 'year' => y } }.reverse
          when 'monthly'
            min = ids.min_by { |id| [id['year'], id['month']] }
            max = ids.max_by { |id| [id['year'], id['month']] }
            result = []
            y = min['year']
            m = min['month']
            until y > max['year'] || (y == max['year'] && m > max['month'])
              result << { 'year' => y, 'month' => m }
              m += 1
              if m > 12
                m = 1
                y += 1
              end
            end
            result.reverse
          when 'quarterly'
            min = ids.min_by { |id| [id['year'], id['quarter'].to_i] }
            max = ids.max_by { |id| [id['year'], id['quarter'].to_i] }
            result = []
            y = min['year']
            q = min['quarter'].to_i
            until y > max['year'] || (y == max['year'] && q > max['quarter'].to_i)
              result << { 'year' => y, 'quarter' => q }
              q += 1
              if q > 4
                q = 1
                y += 1
              end
            end
            result.reverse
          end
        end

        def period_to_s_lines
          return [] unless period && period_data&.any?

          data_by_key = period_data.index_by { |e| period_key(e['_id']) }
          all_period_ids.map do |id|
            entry = data_by_key[period_key(id)]
            sups = entry&.fetch('sups_count', 0) || 0
            if sups.positive?
              rounds = entry['rounds_count']
              positive = entry['positive_outcomes_count']
              reported = entry['reported_outcomes_count']
              "#{period_label(id)}: Facilitated #{pluralize(sups, 'S\'Up')} in #{pluralize(rounds, 'round')} " \
                "with #{positive * 100 / sups}% positive outcomes from #{reported * 100 / sups}% outcomes reported."
            else
              "#{period_label(id)}: No S'Ups."
            end
          end
        end
      end
    end
  end
end
