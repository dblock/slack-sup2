module Api
  module Presenters
    module TeamPresenter
      include Roar::JSON::HAL
      include Roar::Hypermedia
      include Grape::Roar::Representer
      include BasePresenter

      property :id, type: String, desc: 'Team ID.'
      property :team_id, type: String, desc: 'Slack team ID.'
      property :name, type: String, desc: 'Team name.'
      property :domain, type: String, desc: 'Team domain.'
      property :active, type: Grape::API::Boolean, desc: 'Team is active.'
      property :subscribed, type: Grape::API::Boolean, desc: 'Team is a paid subscriber.'
      property :subscribed_at, type: DateTime, desc: 'Date/time when a subscription was purchased.'
      property :created_at, type: DateTime, desc: 'Date/time when the team was created.'
      property :updated_at, type: DateTime, desc: 'Date/time when the team was updated.'

      link :channels do |opts|
        "#{base_url(opts)}/api/channels?team_id=#{id}"
      end

      link :stats do |opts|
        "#{base_url(opts)}/api/stats?team_id=#{id}"
      end

      link :self do |opts|
        "#{base_url(opts)}/api/teams/#{id}"
      end
    end
  end
end
