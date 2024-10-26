module Api
  module Endpoints
    class DataEndpoint < Grape::API
      format :binary
      helpers Api::Helpers::AuthHelpers

      namespace :data do
        desc 'Get data.'
        params do
          requires :team_id, type: String, desc: 'Required team ID.'
          optional :channel_id, type: String, desc: 'Optional channel ID.'
        end
        get do
          team = Team.find(_id: params[:team_id]) || error!('Team Not Found', 404)
          channel = team.channels.find(params[:channel_id]) || error!('Channel Not Found', 404) if params[:channel_id]

          target = channel || team
          authorize_short_lived_token! target

          Dir.mktmpdir('slack-sup-') do |dir|
            filename = target.export_zip!(dir)
            Api::Middleware.logger.info "Sending #{ByteSize.new(File.size(filename))} data file for #{target}"
            content_type 'application/zip'
            header['Content-Disposition'] = "attachment; filename=#{File.basename(filename)}"
            File.binread filename
          end
        end
      end
    end
  end
end
