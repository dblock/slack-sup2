# frozen_string_literal: true

require 'spec_helper'

describe 'events/member_left_channel' do
  include_context 'event'

  let(:event) do
    {
      type: 'member_left_channel',
      team: team.team_id,
      channel: 'channel_id',
      channel_type: 'C'
    }
  end

  it 'does nothing' do
    post '/api/slack/event', event_envelope
    expect(last_response.status).to eq 201
    expect(JSON.parse(last_response.body)).to eq('ok' => true)
  end
end
