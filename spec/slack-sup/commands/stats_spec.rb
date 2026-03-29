require 'spec_helper'

describe SlackSup::Commands::Stats do
  context 'dm' do
    include_context 'subscribed team'

    it 'returns global team stats' do
      expect(message: '@sup stats', channel: 'DM').to respond_with_slack_message(
        "Team S'Up is not in any channels. Invite S'Up to a channel with some users to get started!"
      )
    end
  end

  context 'channel' do
    include_context 'channel'

    before do
      allow_any_instance_of(Slack::Web::Client).to receive(:conversations_info)
    end

    it 'errors on invalid period' do
      expect(message: '@sup stats weekly').to respond_with_slack_message(
        'Invalid period: weekly. Use yearly, monthly and quarterly.'
      )
    end

    it 'empty stats' do
      expect(message: '@sup stats').to respond_with_slack_message(
        "Channel S'Up connects groups of 3 people on Monday after 9:00 AM every week in <#channel>.\n" \
        "There's only 1 user in this channel. Invite some more users to this channel to get started!"
      )
    end

    context 'with outcomes' do
      let!(:user1) { Fabricate(:user, channel:) }
      let!(:user2) { Fabricate(:user, channel:) }
      let!(:user3) { Fabricate(:user, channel:) }

      before do
        allow(channel).to receive(:sync!)
        allow(channel).to receive(:inform!)
        allow_any_instance_of(Sup).to receive(:dm!)
        Timecop.freeze do
          channel.sup!
          Timecop.travel(Time.now + 1.year)
          channel.sup!
        end
        sup = Sup.first
        expect(sup).not_to be_nil
        sup.update_attributes!(outcome: 'all')
        user2.update_attributes!(opted_in: false)
      end

      it 'reports counts' do
        expect(message: '@sup stats').to respond_with_slack_message(
          "Channel S'Up connects groups of 3 people on Monday after 9:00 AM every week in <#channel>.\n" \
          "The channel S'Up currently only has 2 users opted in. Invite some more users to S'Up!\n" \
          "Facilitated 2 S'Ups in 2 rounds for 3 users creating 3 unique connections with 50% positive outcomes from 50% outcomes reported."
        )
      end

      context 'with yearly period' do
        let(:year) { Time.now.year }

        it 'reports yearly breakdown' do
          expect(message: '@sup stats yearly').to respond_with_slack_message(
            "Channel S'Up connects groups of 3 people on Monday after 9:00 AM every week in <#channel>.\n" \
            "The channel S'Up currently only has 2 users opted in. Invite some more users to S'Up!\n" \
            "Facilitated 2 S'Ups in 2 rounds for 3 users creating 3 unique connections with 50% positive outcomes from 50% outcomes reported.\n" \
            "#{year + 1}: Facilitated 1 S'Up in 1 round with 0% positive outcomes from 0% outcomes reported.\n" \
            "#{year}: Facilitated 1 S'Up in 1 round with 100% positive outcomes from 100% outcomes reported."
          )
        end
      end

      context 'with monthly period' do
        let(:year) { Time.now.year }
        let(:month_name) { Date::MONTHNAMES[Time.now.month] }

        it 'reports monthly breakdown' do
          expect(message: '@sup stats monthly').to respond_with_slack_message(
            "Channel S'Up connects groups of 3 people on Monday after 9:00 AM every week in <#channel>.\n" \
            "The channel S'Up currently only has 2 users opted in. Invite some more users to S'Up!\n" \
            "Facilitated 2 S'Ups in 2 rounds for 3 users creating 3 unique connections with 50% positive outcomes from 50% outcomes reported.\n" \
            "#{month_name} #{year + 1}: Facilitated 1 S'Up in 1 round with 0% positive outcomes from 0% outcomes reported.\n" \
            "#{month_name} #{year}: Facilitated 1 S'Up in 1 round with 100% positive outcomes from 100% outcomes reported."
          )
        end
      end

      context 'with quarterly period' do
        let(:year) { Time.now.year }
        let(:quarter) { ((Time.now.month - 1) / 3) + 1 }

        it 'reports quarterly breakdown' do
          expect(message: '@sup stats quarterly').to respond_with_slack_message(
            "Channel S'Up connects groups of 3 people on Monday after 9:00 AM every week in <#channel>.\n" \
            "The channel S'Up currently only has 2 users opted in. Invite some more users to S'Up!\n" \
            "Facilitated 2 S'Ups in 2 rounds for 3 users creating 3 unique connections with 50% positive outcomes from 50% outcomes reported.\n" \
            "Q#{quarter} #{year + 1}: Facilitated 1 S'Up in 1 round with 0% positive outcomes from 0% outcomes reported.\n" \
            "Q#{quarter} #{year}: Facilitated 1 S'Up in 1 round with 100% positive outcomes from 100% outcomes reported."
          )
        end
      end
    end
  end
end
