require 'spec_helper'

describe Api::Endpoints::DataEndpoint do
  include Api::Test::EndpointTest

  let!(:team) { Fabricate(:team, api: true) }

  context 'team' do
    it 'returns team stats' do
      get "/api/data?team_id=#{team.id}&access_token=#{team.short_lived_token}"
      expect(last_response.status).to eq 200
      expect(last_response.headers['Content-Type']).to eq 'application/zip'
      expect(last_response.headers['Content-Disposition']).to eq "attachment; filename=#{team.team_id}.zip"
      expect(last_response.body.length).not_to be 0
    end

    it 'does not return team stats with an invalid token' do
      get "/api/data?team_id=#{team.id}&access_token=expired]"
      expect(last_response.status).to eq 401
    end
  end

  context 'channel' do
    let!(:channel) { Fabricate(:channel, team:) }

    it 'returns channel stats' do
      get "/api/data?team_id=#{team.id}&channel_id=#{channel.id}&access_token=#{channel.short_lived_token}"
      expect(last_response.status).to eq 200
      expect(last_response.headers['Content-Type']).to eq 'application/zip'
      expect(last_response.headers['Content-Disposition']).to eq "attachment; filename=#{channel.channel_id}.zip"
      expect(last_response.body.length).not_to be 0
    end

    it 'does not return team stats with an invalid token' do
      get "/api/data?team_id=#{team.id}&channel_id=#{channel.id}&access_token=expired"
      expect(last_response.status).to eq 401
    end

    it 'does not return team stats with a mismatched team' do
      get "/api/data?team_id=#{Fabricate(:team).id}&channel_id=#{channel.id}&access_token=#{channel.short_lived_token}"
      expect(last_response.status).to eq 404
    end

    it 'does not return team stats with a mismatched channel' do
      get "/api/data?team_id=#{team.id}&channel_id=#{Fabricate(:channel, team:).id}&access_token=#{channel.short_lived_token}"
      expect(last_response.status).to eq 401
    end
  end
end