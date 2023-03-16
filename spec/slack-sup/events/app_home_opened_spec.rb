# frozen_string_literal: true

require 'spec_helper'

describe 'events/app_home_opened' do
  include_context :event

  let(:event) do
    {
      type: 'app_home_opened',
      user: 'user_id',
      channel: 'channel_id'
    }
  end

  it 'welcomes user' do
    expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with(
      channel: 'channel_id', text: /Hi there! I'm your team's S'Up bot. Invite me to a channel/
    )

    post '/api/slack/event', event_envelope
    expect(last_response.status).to eq 201
    expect(JSON.parse(last_response.body)).to eq('ok' => true)
  end

  context 'with some channels' do
    let!(:channel) { Fabricate(:channel, team: team) }
    it 'welcomes user' do
      expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with(
        channel: 'channel_id', text: /Hi there! I'm your team's S'Up bot. I connect your teammates in 1 channel/
      )

      post '/api/slack/event', event_envelope
      expect(last_response.status).to eq 201
      expect(JSON.parse(last_response.body)).to eq('ok' => true)
    end
  end
end
