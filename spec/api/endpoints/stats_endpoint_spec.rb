require 'spec_helper'

describe Api::Endpoints::StatsEndpoint do
  include Api::Test::EndpointTest

  context 'global' do
    it 'reports counts' do
      stats = client.stats
      expect(stats.teams_count).to eq 0
      expect(stats.channels_count).to eq 0
      expect(stats.teams_active_count).to eq 0
      expect(stats.channels_enabled_count).to eq 0
      expect(stats.rounds_count).to eq 0
      expect(stats.sups_count).to eq 0
      expect(stats.users_opted_in_count).to eq 0
      expect(stats.users_count).to eq 0
      expect(stats.outcomes).to eq({})
    end
  end

  context 'channel with outcomes' do
    let(:team) { Fabricate(:team) }
    let(:channel) { Fabricate(:channel, team:) }
    let!(:user1) { Fabricate(:user, channel:) }
    let!(:user2) { Fabricate(:user, channel:, user_id: 'slack_id') }
    let!(:user3) { Fabricate(:user, channel:) }
    let!(:channel2) { Fabricate(:channel, team:) }
    let!(:channel2_user1) { Fabricate(:user, channel: channel2) }
    let!(:channel2_user2) { Fabricate(:user, channel: channel2, user_id: 'slack_id') }
    let!(:channel2_user3) { Fabricate(:user, channel: channel2, opted_in: false) }
    let!(:channel3) { Fabricate(:channel, team: Fabricate(:team)) }
    let!(:channel3_user1) { Fabricate(:user, channel: channel3) }
    let!(:channel3_user2) { Fabricate(:user, channel: channel3) }
    let!(:channel3_user3) { Fabricate(:user, channel: channel3) }

    before do
      allow_any_instance_of(Channel).to receive(:sync!)
      allow_any_instance_of(Channel).to receive(:inform!)
      allow_any_instance_of(Sup).to receive(:dm!)
      2.times do
        channel.sup!
        channel2.sup!
        channel3.sup!
        Timecop.travel(Time.now + 1.year)
      end
      Sup.first.update_attributes!(outcome: 'all')
    end

    context 'channel' do
      it 'reports counts' do
        stats = client.stats(channel_id: channel.id)
        expect(stats.rounds_count).to eq 2
        expect(stats.sups_count).to eq 2
        expect(stats.users_in_sups_count).to eq 3
        expect(stats.users_opted_in_count).to eq 3
        expect(stats.users_count).to eq 3
        expect(stats.outcomes).to eq('all' => 1, 'unknown' => 1)
      end

      it 'reports counts for a channel' do
        stats = client.stats(channel_id: channel.id)
        expect(stats.rounds_count).to eq 2
        expect(stats.sups_count).to eq 2
        expect(stats.users_in_sups_count).to eq 3
        expect(stats.users_opted_in_count).to eq 3
        expect(stats.users_count).to eq 3
        expect(stats.outcomes).to eq('all' => 1, 'unknown' => 1)
      end

      it 'reports counts for another channel' do
        stats = client.stats(channel_id: Fabricate(:channel).id)
        expect(stats.rounds_count).to eq 0
        expect(stats.sups_count).to eq 0
        expect(stats.users_in_sups_count).to eq 0
        expect(stats.users_opted_in_count).to eq 0
        expect(stats.users_count).to eq 0
        expect(stats.outcomes).to eq({})
      end

      context 'with a team api token' do
        before do
          client.headers.update('X-Access-Token' => 'token')
          team.update_attributes!(api_token: 'token')
        end

        it 'returns stats' do
          stats = client.stats(channel_id: channel.id)
          expect(stats.rounds_count).to eq 2
          expect(stats.sups_count).to eq 2
        end
      end

      context 'a channel with an api token' do
        before do
          channel.update_attributes!(api_token: 'token', api: true)
        end

        it 'cannot return stats without a token' do
          expect { client.stats(channel_id: channel.id).resource }.to raise_error Faraday::ClientError do |e|
            json = JSON.parse(e.response[:body])
            expect(json['error']).to eq 'Access Denied'
          end
        end

        it 'cannot return stats with an invalid a token' do
          client.headers.update('X-Access-Token' => 'invalid')
          expect { client.stats(channel_id: channel.id).resource }.to raise_error Faraday::ClientError do |e|
            json = JSON.parse(e.response[:body])
            expect(json['error']).to eq 'Access Denied'
          end
        end

        it 'returns stats' do
          client.headers.update('X-Access-Token' => 'token')
          stats = client.stats(channel_id: channel.id)
          expect(stats.sups_count).to eq 2
        end
      end
    end

    context 'team' do
      it 'reports counts' do
        stats = client.stats(team_id: team.id)
        expect(stats.channels_count).to eq 2
        expect(stats.channels_enabled_count).to eq 2
        expect(stats.rounds_count).to eq 4
        expect(stats.sups_count).to eq 4
        expect(stats.users_opted_in_count).to eq 4
        expect(stats.users_in_sups_count).to eq 4
        expect(stats.users_count).to eq 5
        expect(stats.outcomes).to eq('all' => 1, 'unknown' => 3)
      end

      it 'reports counts for another team' do
        stats = client.stats(team_id: Fabricate(:team).id)
        expect(stats.channels_count).to eq 0
        expect(stats.channels_enabled_count).to eq 0
        expect(stats.rounds_count).to eq 0
        expect(stats.sups_count).to eq 0
        expect(stats.users_in_sups_count).to eq 0
        expect(stats.users_opted_in_count).to eq 0
        expect(stats.users_count).to eq 0
        expect(stats.outcomes).to eq({})
      end

      context 'a team with an api token' do
        before do
          team.update_attributes!(api_token: 'token')
        end

        it 'cannot return stats without a token' do
          expect { client.stats(team_id: team.id).resource }.to raise_error Faraday::ClientError do |e|
            json = JSON.parse(e.response[:body])
            expect(json['error']).to eq 'Access Denied'
          end
        end

        it 'cannot return stats with an invalid a token' do
          client.headers.update('X-Access-Token' => 'invalid')
          expect { client.stats(team_id: team.id).resource }.to raise_error Faraday::ClientError do |e|
            json = JSON.parse(e.response[:body])
            expect(json['error']).to eq 'Access Denied'
          end
        end

        it 'returns stats' do
          client.headers.update('X-Access-Token' => 'token')
          stats = client.stats(team_id: team.id)
          expect(stats.sups_count).to eq 4
        end
      end
    end

    context 'round' do
      let(:round) { channel.rounds.last }

      it 'reports counts for a round' do
        stats = client.stats(round_id: round.id)
        expect(stats.positive_outcomes_count).to eq 0
        expect(stats.reported_outcomes_count).to eq 0
      end

      it 'reports counts for another round' do
        stats = client.stats(round_id: Fabricate(:round).id)
        expect(stats.positive_outcomes_count).to eq 0
        expect(stats.reported_outcomes_count).to eq 0
      end

      context 'with a team api token' do
        before do
          client.headers.update('X-Access-Token' => 'token')
          team.update_attributes!(api_token: 'token')
        end

        it 'returns stats' do
          stats = client.stats(round_id: round.id)
          round.sups.last.update_attributes!(outcome: 'all')
          expect(stats.positive_outcomes_count).to eq 1
          expect(stats.reported_outcomes_count).to eq 1
        end
      end

      context 'a channel with an api token' do
        before do
          channel.update_attributes!(api_token: 'token', api: true)
        end

        it 'cannot return stats without a token' do
          expect { client.stats(round_id: round.id).resource }.to raise_error Faraday::ClientError do |e|
            json = JSON.parse(e.response[:body])
            expect(json['error']).to eq 'Access Denied'
          end
        end

        it 'cannot return stats with an invalid a token' do
          client.headers.update('X-Access-Token' => 'invalid')
          expect { client.stats(round_id: round.id).resource }.to raise_error Faraday::ClientError do |e|
            json = JSON.parse(e.response[:body])
            expect(json['error']).to eq 'Access Denied'
          end
        end

        it 'returns stats' do
          client.headers.update('X-Access-Token' => 'token')
          stats = client.stats(round_id: round.id)
          expect(stats.positive_outcomes_count).to eq 0
          expect(stats.reported_outcomes_count).to eq 0
        end
      end
    end
  end
end
