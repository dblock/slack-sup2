module Api
  module Presenters
    module RoundStatsPresenter
      include Roar::JSON::HAL
      include Roar::Hypermedia
      include Grape::Roar::Representer
      include BasePresenter

      property :positive_outcomes_count
      property :reported_outcomes_count

      link :self do |opts|
        "#{base_url(opts)}/api/stats?round_id=#{round.id}"
      end

      link :round do |opts|
        "#{base_url(opts)}/api/rounds/#{round.id}"
      end
    end
  end
end
