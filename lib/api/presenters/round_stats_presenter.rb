module Api
  module Presenters
    module RoundStatsPresenter
      include Roar::JSON::HAL
      include Roar::Hypermedia
      include Grape::Roar::Representer

      link :self do |opts|
        next unless opts.key?(:env)

        "#{base_url(opts)}/api/stats?round_id=#{round.id}"
      end

      property :positive_outcomes_count
      property :reported_outcomes_count

      def base_url(opts)
        request = Grape::Request.new(opts[:env])
        request.base_url
      end
    end
  end
end