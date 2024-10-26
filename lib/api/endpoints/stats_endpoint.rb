module Api
  module Endpoints
    class StatsEndpoint < Grape::API
      format :json

      helpers Api::Helpers::AuthHelpers

      namespace :stats do
        desc 'Get stats.'
        params do
          optional :team_id, type: String, desc: 'Optional team ID.'
          optional :channel_id, type: String, desc: 'Optional channel ID.'
          optional :round_id, type: String, desc: 'Optional round ID.'
          mutually_exclusive :channel_id, :team_id, :round_id
        end
        get do
          if params[:team_id]
            team = Team.find(_id: params[:team_id]) || error!('Not Found', 404)
            authorize_team! team
            present TeamStats.new(team), with: Api::Presenters::TeamStatsPresenter
          elsif params[:channel_id]
            channel = Channel.find(_id: params[:channel_id]) || error!('Not Found', 404)
            authorize_channel! channel
            present ChannelStats.new(channel), with: Api::Presenters::ChannelStatsPresenter
          elsif params[:round_id]
            round = Round.find(_id: params[:round_id]) || error!('Not Found', 404)
            authorize_channel! round.channel
            present RoundStats.new(round), with: Api::Presenters::RoundStatsPresenter
          else
            present Stats.new, with: Api::Presenters::StatsPresenter
          end
        end
      end
    end
  end
end
