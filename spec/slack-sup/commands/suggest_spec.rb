require 'spec_helper'

describe SlackSup::Commands::Suggest do
  before do
    allow_any_instance_of(Slack::Web::Client).to receive(:conversations_info)
    allow_any_instance_of(Slack::Web::Client).to receive(:users_info) do |_client, user:|
      Hashie::Mash.new(user: { id: user })
    end
  end

  context 'dm' do
    include_context 'channel'

    let!(:suggested_by) { Fabricate(:user, channel:, user_id: 'user', user_name: 'suggested-by') }
    let!(:user1) { Fabricate(:user, channel:, user_id: 'U1', user_name: 'user1') }
    let!(:user2) { Fabricate(:user, channel:, user_id: 'U2', user_name: 'user2') }

    before do
      allow_any_instance_of(Sup).to receive(:dm!)
    end

    it 'creates a team-scoped suggested sup' do
      expect(message: '@sup suggest <@U1> <@U2>', channel: 'DM').to respond_with_slack_message(
        "Suggested a S'Up for #{user1.slack_mention} and #{user2.slack_mention}."
      )

      sup = Sup.desc(:_id).first
      expect(sup.channel).to be_nil
      expect(sup.team).to eq team
      expect(sup.suggested_by.user_id).to eq 'user'
      expect(sup.users.map(&:user_id).sort).to eq %w[U1 U2]
      expect(sup.users.map(&:channel_id)).to all(be_nil)
    end
  end

  context 'channel' do
    include_context 'channel'

    let!(:user1) { Fabricate(:user, channel:, user_id: 'U1', user_name: 'user1') }
    let!(:user2) { Fabricate(:user, channel:, user_id: 'U2', user_name: 'user2') }

    before do
      allow_any_instance_of(Sup).to receive(:dm!)
    end

    it 'creates a suggested sup on demand with trailing topic text' do
      expect(message: "@sup suggest #{user1.slack_mention} #{user2.slack_mention} talk about the weather").to respond_with_slack_message(
        "Suggested a S'Up for #{user1.slack_mention} and #{user2.slack_mention}."
      )

      sup = Sup.desc(:_id).first
      expect(sup.round).to be_nil
      expect(sup.channel).to be_nil
      expect(sup.team).to eq team
      expect(sup.suggested_text).to eq 'talk about the weather'
      expect(sup.suggested_by.user_id).to eq 'user'
      expect(sup.users.map(&:user_id).sort).to eq %w[U1 U2]
      expect(sup.users.map(&:channel_id)).to all(be_nil)
    end

    it 'creates a suggested sup for valid Slack mentions without checking Slack' do
      expect(message: '@sup suggest <@U404> <@U1>').to respond_with_slack_message(
        "Suggested a S'Up for <@U404> and #{user1.slack_mention}."
      )

      sup = Sup.desc(:_id).first
      expect(sup.users.map(&:user_id).sort).to eq %w[U1 U404]
      expect(sup.users.map(&:channel_id)).to all(be_nil)
    end

    it 'rejects suggesting yourself' do
      expect(message: "@sup suggest <@user> #{user1.slack_mention}").to respond_with_slack_message(
        "Sorry, you cannot suggest a S'Up for yourself."
      )
    end

    it 'creates a suggested sup even when users met recently' do
      round = Fabricate(:round, channel:)
      Fabricate(:sup, round:, channel:, users: [user1, user2], created_at: 1.day.ago)

      expect(message: "@sup suggest #{user1.slack_mention} #{user2.slack_mention}").to respond_with_slack_message(
        "Suggested a S'Up for #{user1.slack_mention} and #{user2.slack_mention}."
      )

      sup = Sup.desc(:_id).first
      expect(sup.round).to be_nil
      expect(sup.channel).to be_nil
      expect(sup.conversation_id).to be_nil
      expect(sup.suggested_by.user_id).to eq 'user'
    end
  end
end
