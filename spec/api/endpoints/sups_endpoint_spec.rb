require 'spec_helper'

describe Api::Endpoints::SupsEndpoint do
  include Api::Test::EndpointTest

  let!(:team) { Fabricate(:team) }
  let!(:channel) { Fabricate(:channel, api: true, team:) }

  before do
    allow_any_instance_of(Channel).to receive(:inform!)
    @cursor_params = { round_id: round.id.to_s }
  end

  context 'with a round' do
    let!(:round) { Fabricate(:round, channel:) }

    it_behaves_like 'a cursor api', Sup
    it_behaves_like 'a channel token api', Sup

    context 'sup' do
      let(:existing_sup) { Fabricate(:sup, round:) }

      it 'returns a sup' do
        sup = client.sup(id: existing_sup.id)
        expect(sup.id).to eq existing_sup.id.to_s
        expect(sup._links.self._url).to eq "http://example.org/api/sups/#{existing_sup.id}"
      end

      it 'requires auth to update' do
        expect do
          client.sup(id: existing_sup.id)._put(gcal_html_link: 'updated')
        end.to raise_error Faraday::ClientError do |e|
          json = JSON.parse(e.response[:body])
          expect(json['error']).to eq 'Access Denied'
        end
      end

      it 'updates a sup html link and DMs sup' do
        expect_any_instance_of(Sup).to receive(:dm!).with(text: "I've added this S'Up to your Google Calendar: updated")
        client.headers.update('X-Access-Token' => channel.short_lived_token)
        client.sup(id: existing_sup.id)._put(gcal_html_link: 'updated')
        expect(existing_sup.reload.gcal_html_link).to eq 'updated'
      end

      context 'with a team api token' do
        before do
          client.headers.update('X-Access-Token' => 'token')
          team.update_attributes!(api_token: 'token')
        end

        it 'returns a sup using a team API token' do
          sup = client.sup(id: existing_sup.id)
          expect(sup.id).to eq existing_sup.id.to_s
        end
      end
    end

    context 'sups' do
      let!(:sup_1) { Fabricate(:sup, round:) }
      let!(:sup_2) { Fabricate(:sup, round:) }

      it 'returns sups' do
        sups = client.sups(round_id: round.id)
        expect(sups.map(&:id).sort).to eq [sup_1, sup_2].map(&:id).map(&:to_s).sort
      end

      context 'with a team api token' do
        before do
          client.headers.update('X-Access-Token' => 'token')
          team.update_attributes!(api_token: 'token')
        end

        it 'returns sups' do
          sups = client.sups(round_id: round.id)
          expect(sups.map(&:id).sort).to eq [sup_1, sup_2].map(&:id).map(&:to_s).sort
        end
      end
    end
  end
end
