# frozen_string_literal: true

require 'spec_helper'

describe 'events/app_home_opened' do
  include_context :event

  let(:event) do
    {
      type: 'app_home_opened',
      user: 'user_id',
      channel: 'DM'
    }
  end

  it 'welcomes user' do
    expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with(
      channel: 'DM', text: /Hi there! I'm your team's S'Up bot. Invite me to a channel/
    )

    expect do
      post '/api/slack/event', event_envelope
      expect(last_response.status).to eq 201
      expect(JSON.parse(last_response.body)).to eq('ok' => true)
    end.to change(Channel, :count).by(1)

    channel = team.channels.desc(:_id).limit(1).first
    expect(channel.enabled).to be false
    expect(channel.sync).to be false
    expect(channel.channel_id).to eq 'DM'
    expect(channel.users.count).to eq 1
    user = channel.users.first
    expect(user.user_id).to eq 'user_id'
    expect(user.enabled).to be false
    expect(user.opted_in).to be false
    expect(user.sync).to be false
  end

  it 'welcomes user only once' do
    expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with(
      channel: 'DM', text: /Hi there! I'm your team's S'Up bot. Invite me to a channel/
    ).once

    expect do
      2.times { post '/api/slack/event', event_envelope }
    end.to change(Channel, :count).by(1)
  end

  context 'with some channels' do
    let!(:channel) { Fabricate(:channel, team: team) }
    it 'welcomes user' do
      expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with(
        channel: 'DM', text: /Hi there! I'm your team's S'Up bot. I connect your teammates in 1 channel/
      )

      post '/api/slack/event', event_envelope
      expect(last_response.status).to eq 201
      expect(JSON.parse(last_response.body)).to eq('ok' => true)
    end
  end
end
