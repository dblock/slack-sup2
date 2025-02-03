require 'spec_helper'

describe Api::Endpoints::DataEndpoint do
  include Api::Test::EndpointTest

  include_context 'uses temp dir'

  let!(:team) { Fabricate(:team, api: true) }

  context 'team' do
    let!(:export) { Fabricate(:team_export, team: team) }

    it 'does not return team stats with an invalid token' do
      get "/api/data/#{export.id}?access_token=expired"
      expect(last_response.status).to eq 401
    end

    it 'does not return team stats before they are exported' do
      get "/api/data/#{export.id}?access_token=#{CGI.escape(export.short_lived_token)}"
      expect(last_response.status).to eq 404
      expect(last_response.body).to eq 'Data Not Ready'
    end

    context 'exported' do
      before do
        allow(export).to receive(:notify!)
        export.export!
      end

      it 'returns team data' do
        get "/api/data/#{export.id}?access_token=#{CGI.escape(export.short_lived_token)}"
        expect(last_response.status).to eq 200
        expect(last_response.headers['Content-Type']).to eq 'application/zip'
        expect(last_response.headers['Content-Disposition']).to eq "attachment; filename=#{team.team_id}.zip"
        expect(last_response.body.length).not_to be 0
      end
    end
  end

  context 'channel' do
    let!(:channel) { Fabricate(:channel, team:) }
    let!(:export) { Fabricate(:channel_export, channel: channel) }

    it 'does not return team stats with an invalid token' do
      get "/api/data/#{export.id}?access_token=expired"
      expect(last_response.status).to eq 401
    end

    it 'does not channel stats before they are exported' do
      get "/api/data/#{export.id}?access_token=#{CGI.escape(export.short_lived_token)}"
      expect(last_response.status).to eq 404
      expect(last_response.body).to eq 'Data Not Ready'
    end

    context 'exported' do
      before do
        allow(export).to receive(:notify!)
        export.export!
      end

      it 'returns channel data' do
        get "/api/data/#{export.id}?access_token=#{CGI.escape(export.short_lived_token)}"
        expect(last_response.status).to eq 200
        expect(last_response.headers['Content-Type']).to eq 'application/zip'
        expect(last_response.headers['Content-Disposition']).to eq "attachment; filename=#{channel.channel_id}.zip"
        expect(last_response.body.length).not_to be 0
      end
    end
  end
end
