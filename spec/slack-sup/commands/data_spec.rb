require 'spec_helper'

describe SlackSup::Commands::Data do
  context 'dm' do
    include_context 'subscribed team'

    context 'as admin' do
      before do
        allow_any_instance_of(Team).to receive(:short_lived_token).and_return('token')
        allow_any_instance_of(Team).to receive(:is_admin?).and_return(true)
      end

      it 'returns a link to download data' do
        expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with(
          channel: 'DM',
          text: 'Click here to download your team data.',
          attachments: [
            text: '',
            attachment_type: 'default',
            actions: [{
              type: 'button',
              text: 'Download',
              url: "https://sup2.playplay.io/api/data?team_id=#{team.id}&access_token=token"
            }]
          ]
        )

        expect(message: '@sup data', channel: 'DM').to respond_with_slack_message(
          'Click here to download your team data.'
        )
      end
    end

    context 'as non admin' do
      before do
        allow_any_instance_of(Team).to receive(:is_admin?).and_return(false)
      end

      it 'requires an admin' do
        expect(message: '@sup data', channel: 'DM').to respond_with_slack_message(
          "Sorry, only <@#{team.activated_user_id}> or a Slack team admin can download raw data."
        )
      end
    end
  end

  context 'channel' do
    include_context 'user'

    before do
      allow_any_instance_of(Slack::Web::Client).to receive(:conversations_info)
    end

    context 'as admin' do
      before do
        expect_any_instance_of(User).to receive(:channel_admin?).and_return(true)
      end

      it 'tells the user to check DMs' do
        allow(team.slack_client).to receive(:conversations_open).with(
          users: 'user'
        ).and_return(Hashie::Mash.new('channel' => { 'id' => 'D1' }))

        expect(message: '@sup data').to respond_with_slack_message(
          'Hey <@user>, check your DMs for a link.'
        )

        expect(team.slack_client).to have_received(:chat_postMessage).with(
          hash_including(
            {
              channel: 'D1',
              text: 'Click here to download your <#channel> channel data.'
            }
          )
        )

        expect(team.slack_client).to have_received(:chat_postMessage).with(
          channel: 'channel',
          text: 'Hey <@user>, check your DMs for a link.'
        )
      end
    end

    context 'as non admin' do
      before do
        expect_any_instance_of(User).to receive(:channel_admin?).and_return(false)
      end

      it 'requires an admin' do
        expect(message: '@sup data').to respond_with_slack_message(
          "Sorry, only #{channel.channel_admins_slack_mentions} can download raw data."
        )
      end
    end
  end
end
