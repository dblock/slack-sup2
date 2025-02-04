require 'spec_helper'

describe SlackSup::Commands::Admins do
  include_context 'subscribed team'

  context 'dm' do
    it 'shows team admin' do
      expect(message: '@sup admins', channel: 'DM').to respond_with_slack_message("Team admin is <@#{team.activated_user_id}>.")
    end
  end

  context 'channel' do
    before do
      allow_any_instance_of(Slack::Web::Client).to receive(:conversations_info)
    end

    include_context 'channel'

    it 'shows admin' do
      expect(message: '@sup admins').to respond_with_slack_message("Channel admin is <@#{channel.inviter_id}>.")
    end

    context 'with another admin' do
      let!(:another_admin) { Fabricate(:user, channel:, is_admin: true) }
      let!(:another_user) { Fabricate(:user, channel:, is_admin: false) }

      it 'shows admins' do
        expect(message: '@sup admins').to respond_with_slack_message("Channel admins are <@#{channel.inviter_id}> and #{another_admin.slack_mention}.")
      end
    end

    context 'with the team admin in the channel' do
      let!(:team_admin) { Fabricate(:user, channel:, user_id: team.activated_user_id, is_admin: false) }
      let!(:another_admin) { Fabricate(:user, channel:, is_admin: true) }
      let!(:another_user) { Fabricate(:user, channel:, is_admin: false) }

      it 'always includes team admin' do
        expect(channel.channel_admins_slack_mentions.size).to eq 3
        expect(message: '@sup admins').to respond_with_slack_message("Channel admins are #{channel.channel_admins_slack_mentions.and}.")
      end
    end
  end
end
