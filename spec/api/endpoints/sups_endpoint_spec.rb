require 'spec_helper'

describe Api::Endpoints::SupsEndpoint do
  include Api::Test::EndpointTest

  let!(:team) { Fabricate(:team) }
  let!(:channel) { Fabricate(:channel, api: true, team:) }

  before do
    allow_any_instance_of(Channel).to receive(:inform!)
  end

  context 'with a round' do
    let!(:round) { Fabricate(:round, channel:) }

    before do
      @cursor_params = { round_id: round.id.to_s }
    end

    it_behaves_like 'a cursor api', Sup
    it_behaves_like 'a channel token api', Sup

    context 'sup' do
      let!(:user1) { Fabricate(:user, channel:) }
      let!(:user2) { Fabricate(:user, channel:) }
      let!(:user3) { Fabricate(:user, channel:) }
      let(:existing_sup) { Fabricate(:sup, round:, users: [user1, user2, user3]) }

      before do
        allow(channel).to receive(:sync!)
        allow(existing_sup).to receive(:dm!)
        existing_sup.sup!
      end

      it 'returns a sup' do
        sup = client.sup(id: existing_sup.id)
        expect(sup.id).to eq existing_sup.id.to_s
        expect(sup.captain_user_name).to eq existing_sup.captain_user_name
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
        expect_any_instance_of(Sup).to receive(:dm!).with(
          {
            text: "I've added this S'Up to your Google Calendar.",
            attachments: [
              {
                text: '',
                attachment_type: 'default',
                actions: [{
                  type: 'button',
                  text: 'Google Calendar',
                  url: 'updated'
                }]
              }
            ]
          }
        )
        client.headers.update('X-Access-Token' => channel.short_lived_token)
        client.sup(id: existing_sup.id)._put(gcal_html_link: 'updated')
        expect(existing_sup.reload.gcal_html_link).to eq 'updated'
      end

      context 'with a gcal message' do
        before do
          existing_sup.update_attributes!(
            conversation_id: 'channel',
            gcal_message_ts: SecureRandom.hex
          )
        end

        it 'updates a sup html link and DMs sup' do
          expect_any_instance_of(Slack::Web::Client).to receive(:chat_update).with(
            {
              channel: existing_sup.conversation_id,
              ts: existing_sup.gcal_message_ts,
              text: "I've added this S'Up to your Google Calendar.",
              attachments: [
                {
                  text: '',
                  attachment_type: 'default',
                  actions: [{
                    type: 'button',
                    text: 'Google Calendar',
                    url: 'updated'
                  }]
                }
              ]
            }
          )
          client.headers.update('X-Access-Token' => channel.short_lived_token)
          client.sup(id: existing_sup.id)._put(gcal_html_link: 'updated')
          expect(existing_sup.reload.gcal_html_link).to eq 'updated'
        end
      end

      context 'with a team api token' do
        before do
          client.headers.update('X-Access-Token' => 'token')
          team.update_attributes!(api: true, api_token: 'token')
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
          team.update_attributes!(api: true, api_token: 'token')
        end

        it 'returns sups' do
          sups = client.sups(round_id: round.id)
          expect(sups.map(&:id).sort).to eq [sup_1, sup_2].map(&:id).map(&:to_s).sort
        end
      end
    end
  end

  context 'with a suggested sup' do
    let!(:suggested_by) { Fabricate(:user, team:, channel: nil, user_id: 'suggested-by') }
    let!(:user1) { Fabricate(:user, team:, channel: nil) }
    let!(:user2) { Fabricate(:user, team:, channel: nil) }
    let!(:suggested_sup) { Fabricate(:sup, team:, channel: nil, round: nil, users: [user1, user2], suggested_by:, suggested_text: 'talk about the weather') }

    context 'with a team api token' do
      before do
        client.headers.update('X-Access-Token' => 'token')
        team.update_attributes!(api: true, api_token: 'token')
      end

      it 'returns a suggested sup using a team API token' do
        sup = client.sup(id: suggested_sup.id)
        expect(sup.id).to eq suggested_sup.id.to_s
        expect(sup.suggested_text).to eq 'talk about the weather'
        expect(sup._links.suggested_by._url).to eq "http://example.org/api/users/#{suggested_by.id}"
        expect(sup._links).not_to respond_to(:round)
      end
    end
  end
end
