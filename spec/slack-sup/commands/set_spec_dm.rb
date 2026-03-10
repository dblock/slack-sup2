require 'spec_helper'

describe SlackSup::Commands::Set do
  include_context 'subscribed team'

  shared_examples_for 'can view team settings' do
    context 'set' do
      it 'displays all settings' do
        expect(message: '@sup set', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
          "S'Up is not enabled in any channels.\n" \
          "Team data access via the API is on.\n" \
          "#{team.api_url}"
        )
      end

      context 'with a channel' do
        let!(:channel) { Fabricate(:channel, team:) }

        it 'displays all settings' do
          expect(message: '@sup set', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
            "S'Up is enabled in #{channel.slack_mention}.\n" \
            "Team data access via the API is on.\n" \
            "#{team.api_url}"
          )
        end
      end

      context 'with multiple channels' do
        let!(:channel1) { Fabricate(:channel, team:) }
        let!(:channel2) { Fabricate(:channel, team:) }

        it 'displays all settings' do
          expect(message: '@sup set', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
            "S'Up is enabled in 2 channels (#{channel1.slack_mention} and #{channel2.slack_mention}).\n" \
            "Team data access via the API is on.\n" \
            "#{team.api_url}"
          )
        end
      end
    end

    context 'notify' do
      it 'shows no channels when none enabled' do
        expect(message: '@sup set notify', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
          "S'Up is not enabled in any channels."
        )
      end

      context 'with a channel' do
        let!(:channel) { Fabricate(:channel, team:, sup_notify: 'channel') }

        it 'shows current notify setting' do
          expect(message: '@sup set notify', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
            "Round notifications in #{channel.slack_mention} are sent to the channel."
          )
        end
      end
    end

    context 'api' do
      it 'shows current value of API on' do
        team.update_attributes!(api: true)
        expect(message: '@sup set api', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
          "Team data access via the API is on.\n#{team.api_url}"
        )
      end

      it 'shows current value of API off' do
        team.update_attributes!(api: false)
        expect(message: '@sup set api', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
          'Team data access via the API is off.'
        )
      end

      context 'with API_URL' do
        before do
          ENV['API_URL'] = 'http://local.api'
        end

        after do
          ENV.delete 'API_URL'
        end

        it 'shows current value of API on with API URL' do
          team.update_attributes!(api: true)
          expect(message: '@sup set api', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
            "Team data access via the API is on.\nhttp://local.api/teams/#{team.id}"
          )
        end

        it 'shows current value of API off without API URL' do
          team.update_attributes!(api: false)
          expect(message: '@sup set api', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
            'Team data access via the API is off.'
          )
        end
      end
    end

    context 'api token' do
      it "doesn't show current value when API off" do
        team.update_attributes!(api: false)
        expect(message: '@sup set api token', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
          'Team data access via the API is off.'
        )
      end

      context 'with API_URL' do
        before do
          ENV['API_URL'] = 'http://local.api'
        end

        after do
          ENV.delete 'API_URL'
        end

        it 'shows current value of API on with API URL' do
          team.update_attributes!(api: true)
          expect(message: '@sup set api', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
            "Team data access via the API is on.\nhttp://local.api/teams/#{team.id}"
          )
        end

        it 'shows current value of API off without API URL' do
          team.update_attributes!(api: false)
          expect(message: '@sup set api', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
            'Team data access via the API is off.'
          )
        end
      end
    end
  end

  shared_examples_for 'can change team settings' do
    context 'notify' do
      context 'with channels' do
        let!(:channel1) { Fabricate(:channel, team:, sup_notify: 'channel') }
        let!(:channel2) { Fabricate(:channel, team:, sup_notify: 'channel') }

        it 'sets notify to admin for all channels' do
          expect(message: '@sup set notify admin', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
            'Round info in all channels will now be sent to the admin.'
          )
          expect(channel1.reload.sup_notify).to eq 'admin'
          expect(channel2.reload.sup_notify).to eq 'admin'
        end

        it 'sets notify to off for all channels' do
          expect(message: '@sup set notify off', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
            'Round notifications in all channels are now off.'
          )
          expect(channel1.reload.sup_notify).to eq 'off'
          expect(channel2.reload.sup_notify).to eq 'off'
        end

        it 'sets notify to channel for all channels' do
          channel1.update_attributes!(sup_notify: 'admin')
          channel2.update_attributes!(sup_notify: 'off')
          expect(message: '@sup set notify channel', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
            'Round info in all channels will now be sent to the channel.'
          )
          expect(channel1.reload.sup_notify).to eq 'channel'
          expect(channel2.reload.sup_notify).to eq 'channel'
        end

        it 'fails on an invalid notify value' do
          expect(message: '@sup set notify invalid', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
            'Invalid value: invalid.'
          )
        end
      end
    end

    context 'api' do
      it 'enables API' do
        team.update_attributes!(api: false)
        expect(message: '@sup set api on', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
          "Team data access via the API is now on.\n#{SlackRubyBotServer::Service.api_url}/teams/#{team.id}"
        )
        expect(team.reload.api).to be true
      end

      it 'disables API with set' do
        team.update_attributes!(api: true)
        expect(message: '@sup set api off', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
          'Team data access via the API is now off.'
        )
        expect(team.reload.api).to be false
      end
    end

    context 'api token' do
      it 'shows current value of API token' do
        team.update_attributes!(api_token: 'token', api: true)
        expect(message: '@sup set api token', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
          "Team data access via the API is on with an access token `#{team.api_token}`.\n#{team.api_url}"
        )
      end

      it 'rotates api token' do
        allow(SecureRandom).to receive(:hex).and_return('new')
        team.update_attributes!(api: true, api_token: 'old')
        expect(message: '@sup rotate api token', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
          "Team data access via the API is on with a new access token `new`.\n#{team.api_url}"
        )
        expect(team.reload.api_token).to eq 'new'
      end

      it 'unsets api token' do
        team.update_attributes!(api: true, api_token: 'old')
        expect(message: '@sup unset api token', channel: 'DM', user: team.activated_user_id).to respond_with_slack_message(
          "Team data access via the API is now on.\n#{team.api_url}"
        )
        expect(team.reload.api_token).to be_nil
      end
    end

    context 'invalid' do
      it 'errors set' do
        expect(message: '@sup set invalid on', channel: 'DM').to respond_with_slack_message(
          'Invalid global setting _invalid_, see _help_ for available options.'
        )
      end

      it 'errors unset' do
        expect(message: '@sup unset invalid', channel: 'DM').to respond_with_slack_message(
          'Invalid global setting _invalid_, see _help_ for available options.'
        )
      end

      it 'errors rotate' do
        expect(message: '@sup rotate invalid', channel: 'DM').to respond_with_slack_message(
          'Invalid global setting _invalid_, see _help_ for available options.'
        )
      end
    end
  end

  shared_examples_for 'cannot change team settings' do
    context 'notify' do
      let!(:channel) { Fabricate(:channel, team:, sup_notify: 'channel') }

      it 'cannot set notify' do
        expect(message: '@sup set notify admin', channel: 'DM').to respond_with_slack_message(
          "Round notifications in #{channel.slack_mention} are sent to the channel. Only <@#{team.activated_user_id}> or a Slack team admin can change that, sorry."
        )
        expect(channel.reload.sup_notify).to eq 'channel'
      end
    end

    context 'api' do
      it 'cannot enable API' do
        team.update_attributes!(api: false)
        expect(message: '@sup set api on', channel: 'DM').to respond_with_slack_message(
          "Team data access via the API is off. Only <@#{team.activated_user_id}> or a Slack team admin can change that, sorry."
        )
        expect(team.reload.api).to be false
      end
    end

    context 'api token' do
      it 'cannot rotate api token' do
        team.update_attributes!(api: true, api_token: 'old')
        expect(message: '@sup rotate api token', channel: 'DM').to respond_with_slack_message(
          "Team data access via the API is on with an access token visible to admins. Only <@#{team.activated_user_id}> or a Slack team admin can rotate it, sorry."
        )
        expect(team.reload.api_token).to eq 'old'
      end

      it 'cannot unset api token' do
        team.update_attributes!(api: true, api_token: 'old')
        expect(message: '@sup unset api token', channel: 'DM').to respond_with_slack_message(
          "Team data access via the API is on with an access token visible to admins. Only <@#{team.activated_user_id}> or a Slack team admin can unset it, sorry."
        )
        expect(team.reload.api_token).to eq 'old'
      end
    end
  end

  context 'dm' do
    context 'an admin' do
      before do
        allow_any_instance_of(Team).to receive(:is_admin?).and_return(true)
      end

      it_behaves_like 'can view team settings'
      it_behaves_like 'can change team settings'
    end

    context 'not an admin' do
      before do
        allow_any_instance_of(Team).to receive(:is_admin?).and_return(false)
      end

      it_behaves_like 'can view team settings'
      it_behaves_like 'cannot change team settings'
    end
  end
end
