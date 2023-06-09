require 'spec_helper'

describe SlackSup::Commands::Stats do
  context 'dm' do
    include_context :subscribed_team

    it 'returns global team stats' do
      expect(message: '@sup stats', channel: 'DM').to respond_with_slack_message(
        "Team S'Up connects 0 users in 0 channels."
      )
    end
  end
  context 'channel' do
    include_context :channel

    before do
      allow_any_instance_of(Slack::Web::Client).to receive(:conversations_info)
    end

    it 'empty stats' do
      expect(message: '@sup stats').to respond_with_slack_message(
        "Channel S'Up connects groups of 3 people on Monday after 9:00 AM every week in <#channel>.\n" \
        "Channel S'Up started 3 weeks ago."
      )
    end
    context 'with outcomes' do
      let!(:user1) { Fabricate(:user, channel: channel) }
      let!(:user2) { Fabricate(:user, channel: channel) }
      let!(:user3) { Fabricate(:user, channel: channel) }
      before do
        allow(channel).to receive(:sync!)
        allow_any_instance_of(Sup).to receive(:dm!)
        Timecop.freeze do
          channel.sup!
          Timecop.travel(Time.now + 1.year)
          channel.sup!
        end
        sup = Sup.first
        expect(sup).to_not be nil
        sup.update_attributes!(outcome: 'all')
        user2.update_attributes!(opted_in: false)
      end
      it 'reports counts' do
        expect(message: '@sup stats').to respond_with_slack_message(
          "Channel S'Up connects groups of 3 people on Monday after 9:00 AM every week in <#channel>.\n" \
          "Channel S'Up started 3 weeks ago with 66% (2/3) of users opted in.\n" \
          "Facilitated 2 S'Ups in 2 rounds for 3 users with 50% positive outcomes from 50% outcomes reported."
        )
      end
    end
  end
end
