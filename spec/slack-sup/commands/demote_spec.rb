require 'spec_helper'

describe SlackSup::Commands::Demote do
  before do
    allow_any_instance_of(Slack::Web::Client).to receive(:conversations_info)
  end

  context 'dm' do
    include_context 'subscribed team'

    it 'does not demote' do
      expect(message: '@sup demote', channel: 'DM').to respond_with_slack_message(
        'Please run this command in a channel.'
      )
    end
  end

  context 'channel' do
    include_context 'channel'
    let!(:user2) { Fabricate(:user, channel:) }

    context 'as admin' do
      before do
        expect_any_instance_of(User).to receive(:channel_admin?).and_return(true)
      end

      it 'cannot demote self' do
        expect(message: '@sup demote <@user>').to respond_with_slack_message(
          'Sorry, you cannot demote yourself.'
        )
      end

      it 'demotes a user' do
        user2.update_attributes!(is_admin: true)
        expect(message: "@sup demote #{user2.slack_mention}").to respond_with_slack_message(
          "User #{user2.slack_mention} is no longer S'Up channel admin."
        )
        expect(user2.reload.is_admin).to be false
      end

      it 'says user already demoted' do
        user2.update_attributes!(is_admin: false)
        expect(message: "@sup demote #{user2.slack_mention}").to respond_with_slack_message(
          "User #{user2.slack_mention} is not S'Up channel admin."
        )
        expect(user2.reload.is_admin).to be false
      end

      it 'errors on an invalid user' do
        expect(message: '@sup demote foobar').to respond_with_slack_message(
          "I don't know who foobar is!"
        )
      end

      it 'errors on no user' do
        expect(message: '@sup demote').to respond_with_slack_message(
          'Sorry, demote @someone.'
        )
      end
    end

    context 'as non admin' do
      include_context 'user'

      before do
        expect_any_instance_of(User).to receive(:channel_admin?).and_return(false)
      end

      it 'requires an admin' do
        expect(message: '@sup demote someone').to respond_with_slack_message(
          "Sorry, only #{channel.channel_admins_slack_mentions} can demote users."
        )
      end
    end
  end
end
