require 'spec_helper'

describe Api::Endpoints::SlackEndpoint do
  include Api::Test::EndpointTest

  before do
    allow_any_instance_of(Slack::Events::Request).to receive(:verify!)
    allow_any_instance_of(Channel).to receive(:inform!)
  end

  context 'outcome' do
    let(:sup) { Fabricate(:sup) }

    let(:payload) do
      {
        type: 'interactive_message',
        user: { id: 'user_id' },
        team: { id: 'team_id' },
        callback_id: sup.id.to_s,
        channel: { id: '424242424', name: 'directmessage' },
        original_message: {
          ts: '1467321295.000010'
        },
        response_url: 'https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX',
        token: 'deprecated'
      }
    end

    {
      'all' => 'Glad you all met! Thanks for letting me know.',
      'some' => 'Glad to hear that some of you could meet! Thanks for letting me know.',
      'later' => "Thanks, I'll ask again in a couple of days.",
      'none' => "Sorry to hear that you couldn't meet. Thanks for letting me know."
    }.each_pair do |key, message|
      context 'none' do
        it 'updates outcome' do
          expect(Faraday).to receive(:post).with('https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXXXXXX', {
            response_type: 'in_channel',
            thread_ts: '1467321295.000010',
            text: message,
            attachments: [
              { text: '',
                attachment_type: 'default',
                actions: [
                  { name: 'outcome', text: 'We All Met', type: 'button', value: 'all', style: key == 'all' ? 'primary' : 'default' },
                  { name: 'outcome', text: 'Some of Us Met', type: 'button', value: 'some', style: key == 'some' ? 'primary' : 'default' },
                  { name: 'outcome', text: "We Haven't Met Yet", type: 'button', value: 'later', style: key == 'later' ? 'primary' : 'default' },
                  { name: 'outcome', text: "We Couldn't Meet", type: 'button', value: 'none', style: key == 'none' ? 'primary' : 'default' }
                ],
                callback_id: sup.id.to_s }
            ]
          }.to_json, 'Content-Type' => 'application/json')
          post '/api/slack/action', payload: payload.merge(
            actions: [
              { name: 'outcome', type: 'button', value: key }
            ]
          ).to_json
          expect(last_response.status).to eq 204
          expect(sup.reload.outcome).to eq key
        end
      end
    end

    context 'for a suggested sup' do
      let!(:channel) { Fabricate(:channel) }
      let!(:suggested_by) { Fabricate(:user, channel:, user_id: 'suggested-by') }
      let(:sup) { Fabricate(:sup, channel:, round: nil, suggested_by:) }

      before do
        sup.users << Fabricate(:user, channel:, user_id: 'U1')
        sup.users << Fabricate(:user, channel:, user_id: 'U2')
      end

      it 'notifies the suggestor on a terminal outcome' do
        expect(Faraday).to receive(:post)
        expect_any_instance_of(Slack::Web::Client).to receive(:conversations_open).with(users: 'suggested-by').and_return(
          Hashie::Mash.new(channel: { id: 'suggestor-dm' })
        )
        expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with(
          channel: 'suggestor-dm',
          text: "#{sup.users.map(&:slack_mention).and} updated the S'Up you suggested. Glad you all met! Thanks for letting me know.",
          as_user: true
        )

        post '/api/slack/action', payload: payload.merge(
          callback_id: sup.id.to_s,
          actions: [
            { name: 'outcome', type: 'button', value: 'all' }
          ]
        ).to_json

        expect(last_response.status).to eq 204
      end

      context 'when team-scoped' do
        let!(:team) { Fabricate(:team) }
        let!(:channel) { Fabricate(:channel, team:) }
        let!(:suggested_by) { Fabricate(:user, team:, channel: nil, user_id: 'suggested-by') }
        let(:sup) { Fabricate(:sup, team:, channel: nil, round: nil, suggested_by:) }

        it 'logs the team instead of a nil channel' do
          expect(Faraday).to receive(:post)
          expect(Api::Middleware.logger).to receive(:info).with(
            a_string_starting_with('Updated team ').and(
              a_string_including(", sup #{sup} outcome to 'all'.")
            )
          )
          expect_any_instance_of(Slack::Web::Client).to receive(:conversations_open).with(users: 'suggested-by').and_return(
            Hashie::Mash.new(channel: { id: 'suggestor-dm' })
          )
          expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage)

          post '/api/slack/action', payload: payload.merge(
            callback_id: sup.id.to_s,
            actions: [
              { name: 'outcome', type: 'button', value: 'all' }
            ]
          ).to_json

          expect(last_response.status).to eq 204
        end
      end
    end
  end

  it 'requires payload' do
    post '/api/slack/action'
    expect(last_response.status).to eq 400
    expect(JSON.parse(last_response.body)['message']).to eq 'Invalid parameters.'
  end

  it 'requires payload with actions' do
    post '/api/slack/action', payload: {}.to_json
    expect(last_response.status).to eq 400
    expect(JSON.parse(last_response.body)['type']).to eq 'param_error'
  end
end
