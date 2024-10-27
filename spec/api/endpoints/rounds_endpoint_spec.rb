require 'spec_helper'

describe Api::Endpoints::RoundsEndpoint do
  include Api::Test::EndpointTest

  let!(:channel) { Fabricate(:channel, api: true, sup_odd: false) }

  before do
    @cursor_params = { channel_id: channel.id.to_s }
    allow_any_instance_of(Channel).to receive(:inform!)
  end

  it_behaves_like 'a cursor api', Round
  it_behaves_like 'a channel token api', Round

  context 'round' do
    let(:last_round) { channel.rounds.last }

    before do
      4.times { Fabricate(:user, channel:) }
      allow(channel).to receive(:sync!)
      allow_any_instance_of(Sup).to receive(:dm!)
      channel.sup!
    end

    it 'returns a round' do
      round = client.round(id: last_round.id)
      expect(round.id).to eq last_round.id.to_s
      expect(round.paired_users_count).to eq 3
      expect(round.paired_users.length).to eq 3
      expect(round.missed_users_count).to eq 1
      expect(round.missed_users.length).to eq 1
      expect(round._links.self._url).to eq "http://example.org/api/rounds/#{last_round.id}"
    end

    context 'with a team api token' do
      before do
        client.headers.update('X-Access-Token' => 'token')
        last_round.channel.team.update_attributes!(api_token: 'token')
      end

      it 'returns a round using a team API token' do
        round = client.round(id: last_round.id)
        expect(round.id).to eq last_round.id.to_s
      end
    end
  end

  context 'rounds' do
    let!(:round_1) { Fabricate(:round, channel:) }
    let!(:round_2) { Fabricate(:round, channel:) }

    it 'returns rounds' do
      rounds = client.rounds(channel_id: channel.id)
      expect(rounds.map(&:id).sort).to eq [round_1, round_2].map(&:id).map(&:to_s).sort
    end
  end
end
