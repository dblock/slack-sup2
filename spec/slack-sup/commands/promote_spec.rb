require 'spec_helper'

describe SlackSup::Commands::Promote do
  before do
    allow_any_instance_of(Slack::Web::Client).to receive(:conversations_info)
  end
  context 'dm' do
    include_context :subscribed_team

    it 'does not promote' do
      expect(message: '@sup promote', channel: 'DM').to respond_with_slack_message(
        'Please run this command in a channel.'
      )
    end
  end
  context 'channel' do
    include_context :channel
    let!(:user2) { Fabricate(:user, channel: channel) }

    context 'as admin' do
      before do
        expect_any_instance_of(User).to receive(:channel_admin?).and_return(true)
      end
      it 'cannot promote self' do
        expect(message: '@sup promote <@user>').to respond_with_slack_message(
          'Sorry, you cannot promote yourself.'
        )
      end
      it 'promotes a user' do
        user2.update_attributes!(is_admin: false)
        expect(message: "@sup promote #{user2.slack_mention}").to respond_with_slack_message(
          "User #{user2.slack_mention} is now S'Up channel admin."
        )
        expect(user2.reload.is_admin).to be true
      end
      it 'says user already promoted' do
        user2.update_attributes!(is_admin: true)
        expect(message: "@sup promote #{user2.slack_mention}").to respond_with_slack_message(
          "User #{user2.slack_mention} is already S'Up channel admin."
        )
        expect(user2.reload.is_admin).to be true
      end
      it 'errors on an invalid user' do
        expect(message: '@sup promote foobar').to respond_with_slack_message(
          "I don't know who foobar is!"
        )
      end
      it 'errors on no user' do
        expect(message: '@sup promote').to respond_with_slack_message(
          'Sorry, promote @someone.'
        )
      end
    end
    context 'as non admin' do
      include_context :user

      before do
        expect_any_instance_of(User).to receive(:channel_admin?).and_return(false)
      end
      it 'requires an admin' do
        expect(message: '@sup promote someone').to respond_with_slack_message(
          "Sorry, only #{channel.channel_admins_slack_mentions} can promote users."
        )
      end
    end
  end
end
