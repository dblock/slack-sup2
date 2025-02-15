require 'spec_helper'

describe SlackSup::Commands::Data do
  before do
    allow_any_instance_of(Channel).to receive(:sync!)
    allow_any_instance_of(Channel).to receive(:inform!)
  end

  context 'dm' do
    include_context 'subscribed team'

    context 'as admin' do
      before do
        allow_any_instance_of(Team).to receive(:is_admin?).and_return(true)
      end

      it 'errors without rounds' do
        expect do
          expect(message: '@sup data 100', channel: 'DM').to respond_with_slack_message(
            "Sorry, I didn't find any rounds, try `all` to get all data."
          )
        end.not_to change(Export, :count)
      end

      it 'errors with an invalid number of rounds' do
        expect do
          expect(message: '@sup data -1', channel: 'DM').to respond_with_slack_message(
            'Sorry, -1 is not a valid number of rounds.'
          )
        end.not_to change(Export, :count)
      end

      context 'with 3 most recent rounds' do
        let(:channel) { Fabricate(:channel, team: team) }
        let(:another_channel) { Fabricate(:channel, team: team) }

        before do
          3.times { channel.sup! }
          another_channel.sup!
        end

        it 'prepares team data' do
          expect do
            expect(message: '@sup data', channel: 'DM').to respond_with_slack_message(
              'Hey <@user>, we will prepare your team data for the most recent round in the next few minutes, please check your DMs for a link.'
            )
          end.to change(Export, :count).by(1)
        end

        it 'prepares team data for the last N rounds' do
          expect(message: '@sup data 3', channel: 'DM').to respond_with_slack_message(
            'Hey <@user>, we will prepare your team data for 3 most recent rounds in the next few minutes, please check your DMs for a link.'
          )
          export = team.exports.last
          expect(export.max_rounds_count).to eq 3
        end

        it 'prepares team data for all rounds' do
          expect(message: '@sup data all', channel: 'DM').to respond_with_slack_message(
            'Hey <@user>, we will prepare your team data for all rounds in the next few minutes, please check your DMs for a link.'
          )
          export = team.exports.last
          expect(export.max_rounds_count).to be_nil
        end

        it 'errors telling the caller the max number of rounds available across channels' do
          expect do
            expect(team.max_rounds_count).to eq 3
            expect(message: '@sup data 100', channel: 'DM').to respond_with_slack_message(
              'Sorry, I only found 3 rounds, try 1, 3 or `all`.'
            )
          end.not_to change(Export, :count)
        end

        it 'does not allow for more than one active request' do
          Export.create!(team: team, user_id: 'user', exported: false)

          expect do
            expect(message: '@sup data', channel: 'DM').to respond_with_slack_message(
              'Hey <@user>, we are still working on your previous request.'
            )
          end.not_to change(Export, :count)
        end

        it 'allow for more than one active request once the previous one is completed' do
          Export.create!(team: team, user_id: 'user', exported: true)

          expect do
            expect(message: '@sup data', channel: 'DM').to respond_with_slack_message(
              'Hey <@user>, we will prepare your team data for the most recent round in the next few minutes, please check your DMs for a link.'
            )
          end.to change(Export, :count).by(1)
        end
      end

      it 'errors on channel' do
        expect do
          expect(message: '@sup data <#channel>', channel: 'DM').to respond_with_slack_message(
            "Sorry, <#channel> is not a S'Up channel."
          )
        end.not_to change(Export, :count)
      end

      context 'with a channel' do
        let(:channel) { Fabricate(:channel, team:) }

        it 'errors without rounds' do
          expect do
            expect(message: "@sup data #{channel.slack_mention} 100", channel: 'DM').to respond_with_slack_message(
              "Sorry, I didn't find any rounds, try `all` to get all data."
            )
          end.not_to change(Export, :count)
        end

        it 'errors with an invalid number of rounds' do
          expect do
            expect(message: "@sup data #{channel.slack_mention} -1", channel: 'DM').to respond_with_slack_message(
              'Sorry, -1 is not a valid number of rounds.'
            )
          end.not_to change(Export, :count)
        end

        context 'with 3 most recent rounds' do
          before do
            3.times { channel.sup! }
          end

          it 'prepares team data' do
            expect do
              expect(message: "@sup data #{channel.slack_mention}", channel: 'DM').to respond_with_slack_message(
                "Hey <@user>, we will prepare your #{channel.slack_mention} channel data for the most recent round in the next few minutes, please check your DMs for a link."
              )
            end.to change(Export, :count).by(1)
          end

          it 'prepares team data for the most recent round' do
            expect do
              expect(message: "@sup data #{channel.slack_mention} 1", channel: 'DM').to respond_with_slack_message(
                "Hey <@user>, we will prepare your #{channel.slack_mention} channel data for the most recent round in the next few minutes, please check your DMs for a link."
              )
            end.to change(Export, :count).by(1)
          end

          it 'prepares team data for 3 most recent rounds' do
            expect do
              expect(message: "@sup data #{channel.slack_mention} 3", channel: 'DM').to respond_with_slack_message(
                "Hey <@user>, we will prepare your #{channel.slack_mention} channel data for 3 most recent rounds in the next few minutes, please check your DMs for a link."
              )
            end.to change(Export, :count).by(1)
          end

          it 'prepares all team data' do
            expect do
              expect(message: "@sup data #{channel.slack_mention} all", channel: 'DM').to respond_with_slack_message(
                "Hey <@user>, we will prepare your #{channel.slack_mention} channel data for all rounds in the next few minutes, please check your DMs for a link."
              )
            end.to change(Export, :count).by(1)
          end
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

      context 'with 3 most recent rounds' do
        before do
          3.times { channel.sup! }
        end

        it 'tells the user to check DMs' do
          allow(team.slack_client).to receive(:conversations_open).with(
            users: 'user'
          ).and_return(Hashie::Mash.new('channel' => { 'id' => 'D1' }))

          expect do
            expect(message: '@sup data').to respond_with_slack_message(
              "Hey <@user>, we will prepare your #{user.channel.slack_mention} channel data for the most recent round in the next few minutes, please check your DMs for a link."
            )
          end.to change(Export, :count).by(1)
        end

        it 'can download channel data via a DM' do
          expect do
            expect(message: '@sup data <#channel>', channel: 'DM').to respond_with_slack_message(
              "Hey <@user>, we will prepare your #{user.channel.slack_mention} channel data for the most recent round in the next few minutes, please check your DMs for a link."
            )
          end.to change(Export, :count).by(1)
        end

        it 'does not allow for more than one active request' do
          Export.create!(team: team, channel: channel, user_id: 'user', exported: false)

          expect do
            expect(message: '@sup data <#channel>', channel: 'DM').to respond_with_slack_message(
              'Hey <@user>, we are still working on your previous request.'
            )
          end.not_to change(Export, :count)
        end

        it 'allows for more than one request once a previous one has completed' do
          Export.create!(team: team, channel: channel, user_id: 'user', exported: true)

          expect do
            expect(message: '@sup data <#channel>', channel: 'DM').to respond_with_slack_message(
              "Hey <@user>, we will prepare your #{user.channel.slack_mention} channel data for the most recent round in the next few minutes, please check your DMs for a link."
            )
          end.to change(Export, :count).by(1)
        end
      end
    end

    context 'as non admin' do
      before do
        allow_any_instance_of(Channel).to receive(:is_admin?).and_return(false)
      end

      it 'requires an admin' do
        expect(message: '@sup data').to respond_with_slack_message(
          "Sorry, only #{channel.channel_admins_slack_mentions.or} can download raw data."
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
