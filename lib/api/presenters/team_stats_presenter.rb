module Api
  module Presenters
    module TeamStatsPresenter
      include Roar::JSON::HAL
      include Roar::Hypermedia
      include Grape::Roar::Representer
      include BasePresenter

      link :self do |opts|
        "#{base_url(opts)}/api/stats?team_id=#{team.id}"
      end

      link :team do |opts|
        "#{base_url(opts)}/api/teams/#{team.id}"
      end

      property :rounds_count
      property :sups_count
      property :users_in_sups_count
      property :users_opted_in_count
      property :users_count
      property :channels_count
      property :channels_enabled_count
      property :unique_pairs_count
      property :outcomes
    end
  end
end
