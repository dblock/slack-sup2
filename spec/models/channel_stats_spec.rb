require 'spec_helper'

describe Stats do
  let(:channel) { Fabricate(:channel, sup_wday: Date::MONDAY, sup_followup_wday: Date::THURSDAY) }
  let(:stats) { ChannelStats.new(channel) }
  it 'reports counts' do
    expect(stats.rounds_count).to eq 0
    expect(stats.sups_count).to eq 0
    expect(stats.users_in_sups_count).to eq 0
    expect(stats.users_opted_in_count).to eq 0
    expect(stats.positive_outcomes_count).to eq 0
    expect(stats.reported_outcomes_count).to eq 0
    expect(stats.users_count).to eq 0
    expect(stats.outcomes).to eq({})
    expect(stats.channel).to eq channel
    expect(stats.to_s).to eq [
      "Channel S'Up connects groups of 3 people on Monday after 9:00 AM every week in #{channel.slack_mention}.",
      "There's only 1 user in this channel. Invite some more users to this channel to get started!"
    ].join("\n")
  end
  context 'with one user' do
    let!(:user1) { Fabricate(:user, channel: channel) }
    it 'reports stats' do
      expect(stats.to_s).to eq [
        "Channel S'Up connects groups of 3 people on Monday after 9:00 AM every week in #{channel.slack_mention}.",
        "The channel S'Up currently only has 1 user opted in. Invite some more users to S'Up!"
      ].join("\n")
    end
  end
  context 'with two users' do
    let!(:user1) { Fabricate(:user, channel: channel) }
    let!(:user2) { Fabricate(:user, channel: channel) }
    it 'reports stats' do
      expect(stats.to_s).to eq [
        "Channel S'Up connects groups of 3 people on Monday after 9:00 AM every week in #{channel.slack_mention}.",
        "The channel S'Up currently only has 2 users opted in. Invite some more users to S'Up!"
      ].join("\n")
    end
  end
  context 'with three user' do
    let!(:user1) { Fabricate(:user, channel: channel) }
    let!(:user2) { Fabricate(:user, channel: channel) }
    let!(:user3) { Fabricate(:user, channel: channel) }
    it 'reports stats' do
      expect(stats.to_s).to eq [
        "Channel S'Up connects groups of 3 people on Monday after 9:00 AM every week in #{channel.slack_mention}.",
        "This channel S'Up started 3 weeks ago and has 100% (3/3) of users opted in."
      ].join("\n")
    end
  end
  context 'with three users and one opted out' do
    let!(:user1) { Fabricate(:user, channel: channel) }
    let!(:user2) { Fabricate(:user, channel: channel) }
    let!(:user3) { Fabricate(:user, channel: channel, opted_in: false) }
    it 'reports stats' do
      expect(stats.to_s).to eq [
        "Channel S'Up connects groups of 3 people on Monday after 9:00 AM every week in #{channel.slack_mention}.",
        "The channel S'Up currently only has 2 users opted in. Invite some more users to S'Up!"
      ].join("\n")
    end
  end
  context 'with outcomes' do
    let!(:user1) { Fabricate(:user, channel: channel) }
    let!(:user2) { Fabricate(:user, channel: channel) }
    let!(:user3) { Fabricate(:user, channel: channel) }
    let!(:channel2) { Fabricate(:channel, team: channel.team) }
    let!(:channel2_user1) { Fabricate(:user, channel: channel2) }
    let!(:channel2_user2) { Fabricate(:user, channel: channel2) }
    let!(:channel2_user3) { Fabricate(:user, channel: channel2) }
    before do
      allow_any_instance_of(Channel).to receive(:sync!)
      allow_any_instance_of(Channel).to receive(:inform!)
      allow_any_instance_of(Sup).to receive(:dm!)
      2.times do
        channel.sup!
        channel2.sup!
        Timecop.travel(Time.now + 1.year)
      end
      Sup.first.update_attributes!(outcome: 'all')
    end
    it 'reports counts' do
      expect(stats.rounds_count).to eq 2
      expect(stats.sups_count).to eq 2
      expect(stats.users_in_sups_count).to eq 3
      expect(stats.users_opted_in_count).to eq 3
      expect(stats.users_count).to eq 3
      expect(stats.positive_outcomes_count).to eq 1
      expect(stats.reported_outcomes_count).to eq 1
      expect(stats.outcomes).to eq(all: 1, unknown: 1)
      expect(stats.channel).to eq channel
      expect(stats.to_s).to eq [
        "Channel S'Up connects groups of 3 people on Monday after 9:00 AM every week in #{channel.slack_mention}.",
        "This channel S'Up started 2 years ago and has 100% (3/3) of users opted in.",
        "Facilitated 2 S'Ups in 2 rounds for 3 users with 50% positive outcomes from 50% outcomes reported."
      ].join("\n")
    end
  end
end
