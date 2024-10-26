require 'spec_helper'

describe SlackSup::Commands::Data do
  context 'dm' do
    include_context 'subscribed team'

    context 'as admin' do
      before do
        allow_any_instance_of(Team).to receive(:short_lived_token).and_return('token')
        allow_any_instance_of(Team).to receive(:is_admin?).and_return(true)
      end

      it 'returns a link to download data' do
        expect(message: '@sup data', channel: 'DM').to respond_with_slack_message(
          "Here's a link to download your team data (valid 30 minutes): https://sup2.playplay.io/api/data?team_id=#{team.id}&access_token=token"
        )
      end
    end

    context 'as non admin' do
      before do
        allow_any_instance_of(Team).to receive(:is_admin?).and_return(false)
      end

      it 'requires an admin' do
        expect(message: '@sup data', channel: 'DM').to respond_with_slack_message(
          "Sorry, only <@#{team.activated_user_id}> or a Slack team admin can download raw data."
        )
      end
    end
  end

  context 'channel' do
    include_context 'user'

    before do
      allow_any_instance_of(Slack::Web::Client).to receive(:conversations_info)
    end

    context 'as admin' do
      before do
        expect_any_instance_of(User).to receive(:channel_admin?).and_return(true)
      end

      it 'tells the user to check DMs' do
        allow_any_instance_of(Slack::Web::Client).to receive(:conversations_open).with(
          users: 'user'
        ).and_return(Hashie::Mash.new('channel' => { 'id' => 'D1' }))
        expect(message: '@sup data').to respond_with_slack_message(
          'Hey <@user>, check your DMs for a link.'
        )
      end
    end

    context 'as non admin' do
      before do
        expect_any_instance_of(User).to receive(:channel_admin?).and_return(false)
      end

      it 'requires an admin' do
        expect(message: '@sup data').to respond_with_slack_message(
          "Sorry, only #{channel.channel_admins_slack_mentions} can download raw data."
        )
      end
    end
  end
end
