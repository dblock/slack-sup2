require 'spec_helper'

describe SlackSup::Commands::GCal do
  context 'dm' do
    include_context 'subscribed team'

    before do
      ENV['GOOGLE_API_CLIENT_ID'] = 'client-id'
    end

    after do
      ENV.delete('GOOGLE_API_CLIENT_ID')
    end

    it 'requires a sup' do
      expect(message: '@sup gcal').to respond_with_slack_message(
        "Please `@sup gcal date/time` inside a S'Up DM channel."
      )
    end
  end

  context 'team' do
    let!(:team) { Fabricate(:team) }

    it 'requires a subscription' do
      expect(message: '@sup gcal').to respond_with_slack_message(team.subscribe_text)
    end
  end

  context 'channel' do
    include_context 'channel'

    before do
      allow(channel).to receive(:inform!)
    end

    context 'subscribed team' do
      it 'requires a GOOGLE_API_CLIENT_ID' do
        expect(message: '@sup gcal').to respond_with_slack_message(
          'Missing GOOGLE_API_CLIENT_ID.'
        )
      end

      context 'with GOOGLE_API_CLIENT_ID' do
        before do
          ENV['GOOGLE_API_CLIENT_ID'] = 'client-id'
        end

        after do
          ENV.delete('GOOGLE_API_CLIENT_ID')
        end

        context 'outside of a sup' do
          it 'requires a sup DM' do
            expect(message: '@sup gcal', channel: 'invalid').to respond_with_slack_message(
              "Please `@sup gcal date/time` inside a S'Up DM channel."
            )
          end
        end

        context 'inside a sup' do
          before do
            allow_any_instance_of(Channel).to receive(:inform!)
          end

          let!(:sup) { Fabricate(:sup, channel:, conversation_id: 'sup-channel-id') }
          let(:monday) { DateTime.parse('2017/1/2 8:00 AM EST').utc }

          it 'requires a date/time' do
            expect(message: '@sup gcal', channel: 'sup-channel-id').to respond_with_slack_message(
              'Please specify a date/time, eg. `@sup gcal tomorrow 5pm`.'
            )
          end

          context 'monday' do
            before do
              Timecop.travel(monday).freeze
              allow_any_instance_of(Channel).to receive(:short_lived_token).and_return('token')
            end

            it 'creates a link' do
              expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with(
                {
                  channel: 'sup-channel-id',
                  text: 'Click the button below to create a gcal for Monday, January 02, 2017 at 5:00 pm.',
                  attachments: [
                    {
                      text: '',
                      attachment_type: 'default',
                      actions: [{
                        type: 'button',
                        text: 'Add to Calendar',
                        url: "https://sup2.playplay.io/gcal?sup_id=#{sup.id}&dt=1483394400&access_token=token"
                      }]
                    }
                  ]
                }
              )

              expect(message: '@sup gcal today 5pm', channel: 'sup-channel-id').to respond_with_slack_message(
                'Click the button below to create a gcal for Monday, January 02, 2017 at 5:00 pm.'
              )

              expect(sup.reload.gcal_message_ts).not_to be_nil
            end
          end
        end
      end
    end
  end
end
