require 'spec_helper'

describe SlackSup::Commands::Data do
  context 'dm' do
    include_context 'subscribed team'

    context 'as admin' do
      before do
        allow_any_instance_of(Team).to receive(:is_admin?).and_return(true)
      end

      it 'prepares team data' do
        expect_any_instance_of(Slack::Web::Client).to receive(:chat_postMessage).with(
          channel: 'DM',
          text: 'Hey <@user>, we will prepare your team data in the next few minutes, please check your DMs for a link.'
        )

        expect do
          expect(message: '@sup data', channel: 'DM').to respond_with_slack_message(
            'Hey <@user>, we will prepare your team data in the next few minutes, please check your DMs for a link.'
          )
        end.to change(Export, :count).by(1)

        expect do
          expect(message: '@sup data <#channel>', channel: 'DM').to respond_with_slack_message(
            "Sorry, <#channel> is not a S'Up channel."
          )
        end.not_to change(Export, :count)
      end

      context 'with a channel' do
        let(:channel) { Fabricate(:channel, team:) }

        it 'prepares team data' do
          expect do
            expect(message: "@sup data #{channel.slack_mention}", channel: 'DM').to respond_with_slack_message(
              "Hey <@user>, we will prepare your #{channel.slack_mention} channel data in the next few minutes, please check your DMs for a link."
            )
          end.to change(Export, :count).by(1)
        end
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
        allow_any_instance_of(Channel).to receive(:is_admin?).and_return(true)
      end

      it 'tells the user to check DMs' do
        allow(team.slack_client).to receive(:conversations_open).with(
          users: 'user'
        ).and_return(Hashie::Mash.new('channel' => { 'id' => 'D1' }))

        expect do
          expect(message: '@sup data').to respond_with_slack_message(
            "Hey <@user>, we will prepare your #{user.channel.slack_mention} channel data in the next few minutes, please check your DMs for a link."
          )
        end.to change(Export, :count).by(1)
      end

      it 'can download channel data via a DM' do
        expect do
          expect(message: '@sup data <#channel>', channel: 'DM').to respond_with_slack_message(
            "Hey <@user>, we will prepare your #{user.channel.slack_mention} channel data in the next few minutes, please check your DMs for a link."
          )
        end.to change(Export, :count).by(1)
      end
    end

    context 'as non admin' do
      before do
        allow_any_instance_of(Channel).to receive(:is_admin?).and_return(false)
      end

      it 'requires an admin' do
        expect(message: '@sup data').to respond_with_slack_message(
          "Sorry, only #{channel.channel_admins_slack_mentions} can download raw data."
        )
      end

      it "requires a S'Up channel" do
        expect(message: '@sup data <#another>', channel: 'DM').to respond_with_slack_message(
          "Sorry, <#another> is not a S'Up channel."
        )
      end

      context 'a channel' do
        let(:channel) { Fabricate(:channel, team:) }

        it 'requires a channel admin' do
          expect(message: "@sup data #{channel.slack_mention}", channel: 'DM').to respond_with_slack_message(
            "Sorry, only admins of #{channel.slack_mention}, <@#{team.activated_user_id}>, or a Slack team admin can download channel data."
          )
        end
      end
    end
  end
end
