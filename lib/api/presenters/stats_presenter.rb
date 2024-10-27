module Api
  module Presenters
    module StatsPresenter
      include Roar::JSON::HAL
      include Roar::Hypermedia
      include Grape::Roar::Representer
      include BasePresenter

      property :teams_count
      property :channels_count
      property :teams_active_count
      property :channels_enabled_count
      property :rounds_count
      property :sups_count
      property :users_opted_in_count
      property :users_count
      property :outcomes

      link :self do |opts|
        "#{base_url(opts)}/api/stats"
      end
    end
  end
end
