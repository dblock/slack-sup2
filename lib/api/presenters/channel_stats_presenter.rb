module Api
  module Presenters
    module ChannelStatsPresenter
      include Roar::JSON::HAL
      include Roar::Hypermedia
      include Grape::Roar::Representer
      include BasePresenter

      link :channel do |opts|
        "#{base_url(opts)}/api/channels/#{channel.id}"
      end

      link :self do |opts|
        "#{base_url(opts)}/api/stats?channel_id=#{channel.id}"
      end

      property :rounds_count
      property :sups_count
      property :users_in_sups_count
      property :users_opted_in_count
      property :users_count
      property :unique_pairs_count
      property :outcomes
    end
  end
end
