require 'spec_helper'

describe SlackSup::Commands::Set do
  include_context 'subscribed team'

  def make_message(message, options = {})
    args = {}
    options = options ? options.dup : {}
    target = options.delete(:target)
    args[:message] = target ? message.gsub(/@sup (\w*)/, "@sup \\1 #{target}") : message
    args.merge(options)
  end

  shared_examples_for 'can view channel settings' do |options|
    it 'displays all settings' do
      expect(make_message('@sup set', options)).to respond_with_slack_message(
        "Channel #{channel.slack_mention} S'Up connects groups of max 3 people on Monday after 9:00 AM every week in (GMT-05:00) Eastern Time (US & Canada), taking special care to not pair the same people more frequently than every 12 weeks.\n" \
        "Channel users are _opted in_ by default.\n" \
        "Custom profile team field is _not set_.\n" \
        "Channel data access via the API is on.\n" \
        "#{channel.api_url}"
      )
    end

    context 'opt' do
      it 'shows current value when opted in' do
        channel.update_attributes!(opt_in: true)
        expect(make_message('@sup set opt', options)).to respond_with_slack_message(
          'Users are opted in by default.'
        )
      end

      it 'shows current value when opted out' do
        channel.update_attributes!(opt_in: false)
        expect(make_message('@sup set opt', options)).to respond_with_slack_message(
          'Users are opted out by default.'
        )
      end
    end

    context 'api' do
      it 'shows current value of API on' do
        channel.update_attributes!(api: true)
        expect(make_message('@sup set api', options)).to respond_with_slack_message(
          "Channel data access via the API is on.\n#{channel.api_url}"
        )
      end

      it 'shows current value of API off' do
        channel.update_attributes!(api: false)
        expect(make_message('@sup set api', options)).to respond_with_slack_message(
          'Channel data access via the API is off.'
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
          channel.update_attributes!(api: true)
          expect(make_message('@sup set api', options)).to respond_with_slack_message(
            "Channel data access via the API is on.\nhttp://local.api/channels/#{channel.id}"
          )
        end

        it 'shows current value of API off without API URL' do
          channel.update_attributes!(api: false)
          expect(make_message('@sup set api', options)).to respond_with_slack_message(
            'Channel data access via the API is off.'
          )
        end
      end
    end

    context 'api token' do
      it "doesn't show current value when API off" do
        channel.update_attributes!(api: false)
        expect(make_message('@sup set api token', options)).to respond_with_slack_message(
          'Channel data access via the API is off.'
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
          channel.update_attributes!(api: true)
          expect(make_message('@sup set api', options)).to respond_with_slack_message(
            "Channel data access via the API is on.\nhttp://local.api/channels/#{channel.id}"
          )
        end

        it 'shows current value of API off without API URL' do
          channel.update_attributes!(api: false)
          expect(make_message('@sup set api', options)).to respond_with_slack_message(
            'Channel data access via the API is off.'
          )
        end
      end
    end

    context 'day' do
      it 'defaults to Monday' do
        expect(make_message('@sup set day', options)).to respond_with_slack_message(
          "Channel S'Up is on Monday."
        )
      end

      it 'shows current value of sup day' do
        channel.update_attributes!(sup_wday: Date::TUESDAY)
        expect(make_message('@sup set day', options)).to respond_with_slack_message(
          "Channel S'Up is on Tuesday."
        )
      end
    end

    context 'followup' do
      it 'defaults to Thursday' do
        expect(make_message('@sup set followup', options)).to respond_with_slack_message(
          "Channel S'Up followup day is on Thursday."
        )
      end

      it 'shows current value of sup followup' do
        channel.update_attributes!(sup_followup_wday: Date::TUESDAY)
        expect(make_message('@sup set followup', options)).to respond_with_slack_message(
          "Channel S'Up followup day is on Tuesday."
        )
      end
    end

    context 'time' do
      it 'defaults to 9AM' do
        expect(make_message('@sup set time', options)).to respond_with_slack_message(
          "Channel S'Up is after 9:00 AM #{tzs}."
        )
      end

      it 'shows current value of sup time' do
        channel.update_attributes!(sup_time_of_day: (10 * 60 * 60) + (30 * 60))
        expect(make_message('@sup set time', options)).to respond_with_slack_message(
          "Channel S'Up is after 10:30 AM #{tzs}."
        )
      end
    end

    context 'weeks' do
      it 'defaults to one' do
        expect(make_message('@sup set weeks', options)).to respond_with_slack_message(
          "Channel S'Up is every week."
        )
      end

      it 'shows current value of weeks' do
        channel.update_attributes!(sup_every_n_weeks: 3)
        expect(make_message('@sup set weeks', options)).to respond_with_slack_message(
          "Channel S'Up is every 3 weeks."
        )
      end
    end

    context 'recency' do
      it 'defaults to one' do
        expect(make_message('@sup set recency', options)).to respond_with_slack_message(
          'Taking special care to not pair the same people more than every 12 weeks.'
        )
      end

      it 'shows current value of recency' do
        channel.update_attributes!(sup_recency: 3)
        expect(make_message('@sup set recency', options)).to respond_with_slack_message(
          'Taking special care to not pair the same people more than every 3 weeks.'
        )
      end
    end

    context 'size' do
      it 'defaults to 3' do
        expect(make_message('@sup set size', options)).to respond_with_slack_message(
          "Channel S'Up connects groups of 3 people."
        )
      end

      it 'shows current value of size' do
        channel.update_attributes!(sup_size: 3)
        expect(make_message('@sup set size', options)).to respond_with_slack_message(
          "Channel S'Up connects groups of 3 people."
        )
      end
    end

    context 'odd' do
      it 'shows current value of odd on' do
        channel.update_attributes!(sup_odd: true)
        expect(make_message('@sup set odd', options)).to respond_with_slack_message(
          "Channel S'Up connects groups of max 3 people."
        )
      end

      it 'shows current value of odd off' do
        channel.update_attributes!(sup_odd: false)
        expect(make_message('@sup set odd', options)).to respond_with_slack_message(
          "Channel S'Up connects groups of 3 people."
        )
      end
    end

    context 'timezone' do
      it 'defaults to Eastern Time (US & Canada)' do
        expect(make_message('@sup set timezone', options)).to respond_with_slack_message(
          "Channel S'Up timezone is #{ActiveSupport::TimeZone.new('Eastern Time (US & Canada)')}."
        )
      end

      it 'shows current value of sup timezone' do
        channel.update_attributes!(sup_tz: 'Hawaii')
        expect(make_message('@sup set timezone', options)).to respond_with_slack_message(
          "Channel S'Up timezone is #{ActiveSupport::TimeZone.new('Hawaii')}."
        )
      end
    end

    context 'custom profile team field', vcr: { cassette_name: 'team_profile_get' } do
      it 'is not set by default' do
        expect(make_message('@sup set team field', options)).to respond_with_slack_message(
          'Custom profile team field is _not set_.'
        )
      end

      it 'shows current value' do
        channel.update_attributes!(team_field_label: 'Artsy Team')
        expect(make_message('@sup set team field', options)).to respond_with_slack_message(
          'Custom profile team field is _Artsy Team_.'
        )
      end
    end

    context 'custom sup message' do
      it 'is not set by default' do
        expect(make_message('@sup set message', options)).to respond_with_slack_message(
          "Using the default S'Up message. _#{Sup::PLEASE_SUP_MESSAGE}_"
        )
      end

      it 'shows current value' do
        channel.update_attributes!(sup_message: 'Please meet.')
        expect(make_message('@sup set message', options)).to respond_with_slack_message(
          "Using a custom S'Up message. _Please meet._"
        )
      end
    end

    context 'sync' do
      let!(:requester) { Fabricate(:user, channel:, user_id: 'user') }

      it 'shows next sync' do
        channel.update_attributes!(sync: true)
        expect(make_message('@sup set sync', options)).to respond_with_slack_message(
          'Users will sync in the next hour.'
        )
      end

      it 'shows last sync' do
        channel.update_attributes!(sync: false)
        expect(make_message('@sup set sync', options)).to respond_with_slack_message(
          "Users will sync before the next round. #{channel.next_sup_at_text}"
        )
      end

      it 'shows last sync that had user updates' do
        Timecop.travel(Time.now.utc + 1.minute)
        channel.update_attributes!(last_sync_at: Time.now.utc)
        Fabricate(:user, channel:)
        expect(make_message('@sup set sync', options)).to respond_with_slack_message(
          "Last users sync was less than 1 second ago, 1 user updated. Users will sync before the next round. #{channel.next_sup_at_text}"
        )
      end

      it 'shows last sync that had no user updates' do
        Fabricate(:user, channel:)
        Timecop.travel(Time.now.utc + 1.minute)
        channel.update_attributes!(last_sync_at: Time.now.utc)
        expect(make_message('@sup set sync', options)).to respond_with_slack_message(
          "Last users sync was less than 1 second ago, 0 users updated. Users will sync before the next round. #{channel.next_sup_at_text}"
        )
      end

      it 'shows last sync that had multiple users updates' do
        Timecop.travel(Time.now.utc + 1.minute)
        channel.update_attributes!(last_sync_at: Time.now.utc)
        2.times { Fabricate(:user, channel:) }
        expect(make_message('@sup set sync', options)).to respond_with_slack_message(
          "Last users sync was less than 1 second ago, 2 users updated. Users will sync before the next round. #{channel.next_sup_at_text}"
        )
      end
    end
  end

  shared_examples_for 'can change channel settings' do |options|
    context 'opt' do
      it 'opts in' do
        channel.update_attributes!(opt_in: false)
        expect(make_message('@sup set opt in', options)).to respond_with_slack_message(
          'Users are now opted in by default.'
        )
        expect(channel.reload.opt_in).to be true
      end

      it 'outs out' do
        channel.update_attributes!(opt_in: true)
        expect(make_message('@sup set opt out', options)).to respond_with_slack_message(
          'Users are now opted out by default.'
        )
        expect(channel.reload.opt_in).to be false
      end

      it 'fails on an invalid opt value' do
        expect(make_message('@sup set opt invalid', options)).to respond_with_slack_message(
          'Invalid value: invalid.'
        )
        expect(channel.reload.opt_in).to be true
      end
    end

    context 'api' do
      it 'enables API' do
        channel.update_attributes!(api: false)
        expect(make_message('@sup set api on', options)).to respond_with_slack_message(
          "Channel data access via the API is now on.\n#{SlackRubyBotServer::Service.api_url}/channels/#{channel.id}"
        )
        expect(channel.reload.api).to be true
      end

      it 'disables API with set' do
        channel.update_attributes!(api: true)
        expect(make_message('@sup set api off', options)).to respond_with_slack_message(
          'Channel data access via the API is now off.'
        )
        expect(channel.reload.api).to be false
      end
    end

    context 'api token' do
      it 'shows current value of API token' do
        channel.update_attributes!(api_token: 'token', api: true)
        expect(make_message('@sup set api token', options)).to respond_with_slack_message(
          "Channel data access via the API is on with an access token `#{channel.api_token}`.\n#{channel.api_url}"
        )
      end

      it 'rotates api token' do
        allow(SecureRandom).to receive(:hex).and_return('new')
        channel.update_attributes!(api: true, api_token: 'old')
        expect(make_message('@sup rotate api token', options)).to respond_with_slack_message(
          "Channel data access via the API is on with a new access token `new`.\n#{channel.api_url}"
        )
        expect(channel.reload.api_token).to eq 'new'
      end

      it 'unsets api token' do
        channel.update_attributes!(api: true, api_token: 'old')
        expect(make_message('@sup unset api token', options)).to respond_with_slack_message(
          "Channel data access via the API is now on.\n#{channel.api_url}"
        )
        expect(channel.reload.api_token).to be_nil
      end
    end

    context 'day' do
      it 'changes day' do
        expect(make_message('@sup set day friday', options)).to respond_with_slack_message(
          "Channel S'Up is now on Friday."
        )
        expect(channel.reload.sup_wday).to eq Date::FRIDAY
      end

      context 'on Tuesday' do
        let(:tz) { 'Eastern Time (US & Canada)' }
        let(:tuesday) { DateTime.parse('2017/1/3 8:00 AM EST').utc }

        before do
          Timecop.travel(tuesday)
        end

        it 'changes day to today' do
          expect(make_message('@sup set day today', options)).to respond_with_slack_message(
            "Channel S'Up is now on Tuesday."
          )
          expect(channel.reload.sup_wday).to eq Date::TUESDAY
        end

        it 'changes day to Today' do
          expect(make_message('@sup set day Today', options)).to respond_with_slack_message(
            "Channel S'Up is now on Tuesday."
          )
          expect(channel.reload.sup_wday).to eq Date::TUESDAY
        end
      end

      it 'errors set on an invalid day' do
        expect(make_message('@sup set day foobar', options)).to respond_with_slack_message(
          "Day _foobar_ is invalid, try _Monday_, _Tuesday_, etc. Channel S'Up is on Monday."
        )
      end
    end

    context 'followup' do
      it 'changes followup' do
        expect(make_message('@sup set followup friday', options)).to respond_with_slack_message(
          "Channel S'Up followup day is now on Friday."
        )
        expect(channel.reload.sup_followup_wday).to eq Date::FRIDAY
      end

      it 'errors set on an invalid day' do
        expect(make_message('@sup set followup foobar', options)).to respond_with_slack_message(
          "Day _foobar_ is invalid, try _Monday_, _Tuesday_, etc. Channel S'Up followup day is on Thursday."
        )
      end
    end

    context 'time' do
      it 'changes sup time' do
        expect(make_message('@sup set time 11:20PM', options)).to respond_with_slack_message(
          "Channel S'Up is now after 11:20 PM #{tzs}."
        )
        expect(channel.reload.sup_time_of_day).to eq (23 * 60 * 60) + (20 * 60)
      end

      it 'errors set on an invalid time' do
        expect(make_message('@sup set time foobar', options)).to respond_with_slack_message(
          "Time _foobar_ is invalid. Channel S'Up is after 9:00 AM #{tzs}."
        )
      end
    end

    context 'weeks' do
      it 'changes weeks' do
        expect(make_message('@sup set weeks 2', options)).to respond_with_slack_message(
          "Channel S'Up is now every 2 weeks."
        )
        expect(channel.reload.sup_every_n_weeks).to eq 2
      end

      it 'errors set on an invalid number of weeks' do
        expect(make_message('@sup set weeks foobar', options)).to respond_with_slack_message(
          "Number _foobar_ is invalid. Channel S'Up is every week."
        )
      end
    end

    context 'recency' do
      it 'changes recency' do
        expect(make_message('@sup set recency 2', options)).to respond_with_slack_message(
          'Now taking special care to not pair the same people more than every 2 weeks.'
        )
        expect(channel.reload.sup_recency).to eq 2
      end

      it 'errors set on an invalid number of weeks' do
        expect(make_message('@sup set recency foobar', options)).to respond_with_slack_message(
          'Number _foobar_ is invalid. Taking special care to not pair the same people more than every 12 weeks.'
        )
      end
    end

    context 'size' do
      it 'changes size' do
        expect(make_message('@sup set size 2', options)).to respond_with_slack_message(
          "Channel S'Up now connects groups of 2 people."
        )
        expect(channel.reload.sup_size).to eq 2
      end

      it 'errors set on an invalid number of size' do
        expect(make_message('@sup set size foobar', options)).to respond_with_slack_message(
          "Number _foobar_ is invalid. Channel S'Up connects groups of 3 people."
        )
      end
    end

    context 'odd' do
      it 'enables odd' do
        channel.update_attributes!(sup_odd: false)
        expect(make_message('@sup set odd true', options)).to respond_with_slack_message(
          "Channel S'Up now connects groups of max 3 people."
        )
        expect(channel.reload.sup_odd).to be true
      end

      it 'disables odd with set' do
        channel.update_attributes!(sup_odd: true)
        expect(make_message('@sup set odd false', options)).to respond_with_slack_message(
          "Channel S'Up now connects groups of 3 people."
        )
        expect(channel.reload.sup_odd).to be false
      end
    end

    context 'timezone' do
      it 'changes timezone' do
        expect(make_message('@sup set timezone Hawaii', options)).to respond_with_slack_message(
          "Channel S'Up timezone is now #{ActiveSupport::TimeZone.new('Hawaii')}."
        )
        expect(channel.reload.sup_tz).to eq 'Hawaii'
      end

      it 'errors set on an invalid timezone' do
        expect(make_message('@sup set timezone foobar', options)).to respond_with_slack_message(
          "TimeZone _foobar_ is invalid, see https://github.com/rails/rails/blob/v#{ActiveSupport::VERSION::STRING}/activesupport/lib/active_support/values/time_zone.rb#L30 for a list. Channel S'Up timezone is currently #{ActiveSupport::TimeZone.new('Eastern Time (US & Canada)')}."
        )
      end
    end

    context 'time and time zone together' do
      it 'sets time together with a Hawaii timezone' do
        expect(make_message('@sup set time 10AM Hawaii', options)).to respond_with_slack_message(
          "Channel S'Up is now after 10:00 AM #{Time.now.in_time_zone(ActiveSupport::TimeZone.new('Hawaii')).strftime('%Z')}."
        )
        expect(channel.reload.sup_time_of_day).to eq 10 * 60 * 60
        expect(channel.reload.sup_tz).to eq 'Hawaii'
      end

      it 'sets time together with a PST timezone' do
        expect(make_message('@sup set time 10:00 AM Pacific Time (US & Canada)', options)).to respond_with_slack_message(
          "Channel S'Up is now after 10:00 AM #{Time.now.in_time_zone(ActiveSupport::TimeZone.new('America/Los_Angeles')).strftime('%Z')}."
        )
        expect(channel.reload.sup_time_of_day).to eq 10 * 60 * 60
        expect(channel.reload.sup_tz).to eq 'Pacific Time (US & Canada)'
      end
    end

    context 'custom profile team field', vcr: { cassette_name: 'team_profile_get' } do
      it 'changes value' do
        expect(make_message('@sup set team field Artsy Title', options)).to respond_with_slack_message(
          'Custom profile team field is now _Artsy Title_.'
        )
        expect(channel.reload.team_field_label).to eq 'Artsy Title'
        expect(channel.reload.team_field_label_id).to eq 'Xf6RKY5F2B'
      end

      it 'errors set on an invalid team field' do
        expect(make_message('@sup set team field Invalid Field', options)).to respond_with_slack_message(
          'Custom profile team field _Invalid Field_ is invalid. Possible values are _Artsy Title_, _Artsy Team_, _Artsy Subteam_, _Personality Type_, _Instagram_, _Twitter_, _Facebook_, _Website_.'
        )
      end

      it 'unsets' do
        channel.update_attributes!(team_field_label: 'Artsy Team')
        expect(make_message('@sup unset team field', options)).to respond_with_slack_message(
          'Custom profile team field is now _not set_.'
        )
        expect(channel.reload.team_field_label).to be_nil
        expect(channel.reload.team_field_label_id).to be_nil
      end
    end

    context 'custom sup message' do
      it 'changes value' do
        expect(make_message('@sup set message Hello world!', options)).to respond_with_slack_message(
          "Now using a custom S'Up message. _Hello world!_"
        )
        expect(channel.reload.sup_message).to eq 'Hello world!'
      end

      it 'unsets' do
        channel.update_attributes!(sup_message: 'Updated')
        expect(make_message('@sup unset message', options)).to respond_with_slack_message(
          "Now using the default S'Up message. _#{Sup::PLEASE_SUP_MESSAGE}_"
        )
        expect(channel.reload.sup_message).to be_nil
      end
    end

    context 'invalid' do
      it 'errors set' do
        expect(make_message('@sup set invalid on', options)).to respond_with_slack_message(
          'Invalid channel setting _invalid_, see _help_ for available options.'
        )
      end

      it 'errors unset' do
        expect(make_message('@sup unset invalid', options)).to respond_with_slack_message(
          'Invalid channel setting _invalid_, see _help_ for available options.'
        )
      end

      it 'errors rotate' do
        expect(make_message('@sup rotate invalid', options)).to respond_with_slack_message(
          'Invalid channel setting _invalid_, see _help_ for available options.'
        )
      end
    end

    context 'sync' do
      let!(:requester) { Fabricate(:user, channel:, user_id: 'user') }

      it 'sets sync' do
        channel.update_attributes!(sup_odd: false)
        expect(make_message('@sup set sync now', options)).to respond_with_slack_message(
          'Users will sync in the next hour. Come back and run `set sync` or `stats` in a bit.'
        )
        expect(channel.reload.sync).to be true
      end

      it 'errors on invalid sync value' do
        channel.update_attributes!(sync: false)
        expect(make_message('@sup set sync foobar', options)).to respond_with_slack_message(
          'The option _foobar_ is invalid. Use `now` to schedule a user sync in the next hour.'
        )
        expect(channel.reload.sync).to be false
      end
    end
  end

  shared_examples_for 'cannot change channel settings' do |options|
    context 'api' do
      it 'cannot set opt' do
        expect(make_message('@sup set opt out', options)).to respond_with_slack_message(
          "Users are opted in by default. Only #{channel.channel_admins_slack_mentions.or} can change that, sorry."
        )
      end

      it 'cannot set api' do
        expect(make_message('@sup set api true', options)).to respond_with_slack_message(
          "Channel data access via the API is on. Only #{channel.channel_admins_slack_mentions.or} can change that, sorry."
        )
      end

      it 'does not show current value of API token' do
        channel.update_attributes!(api_token: 'token', api: true)
        expect(make_message('@sup set api token', options)).to respond_with_slack_message(
          "Channel data access via the API is on with an access token visible to admins.\n#{channel.api_url}"
        )
      end

      it 'cannot rotate api token' do
        channel.update_attributes!(api: true, api_token: 'old')
        expect(make_message('@sup rotate api token', options)).to respond_with_slack_message(
          "Channel data access via the API is on with an access token visible to admins. Only #{channel.channel_admins_slack_mentions.or} can rotate it, sorry."
        )
        expect(channel.reload.api_token).to eq 'old'
      end

      it 'cannot unset api token' do
        channel.update_attributes!(api: true, api_token: 'old')
        expect(make_message('@sup unset api token', options)).to respond_with_slack_message(
          "Channel data access via the API is on with an access token visible to admins. Only #{channel.channel_admins_slack_mentions.or} can unset it, sorry."
        )
        expect(channel.reload.api_token).to eq 'old'
      end

      it 'cannot set day' do
        expect(make_message('@sup set day tuesday', options)).to respond_with_slack_message(
          "Channel S'Up is on Monday. Only #{channel.channel_admins_slack_mentions.or} can change that, sorry."
        )
      end

      it 'cannot set time' do
        expect(make_message('@sup set time 11:00 AM', options)).to respond_with_slack_message(
          "Channel S'Up is after 9:00 AM #{tzs}. Only #{channel.channel_admins_slack_mentions.or} can change that, sorry."
        )
      end

      it 'cannot set weeks' do
        expect(make_message('@sup set weeks 2', options)).to respond_with_slack_message(
          "Channel S'Up is every week. Only #{channel.channel_admins_slack_mentions.or} can change that, sorry."
        )
      end

      it 'cannot set followup day' do
        expect(make_message('@sup set followup 2', options)).to respond_with_slack_message(
          "Channel S'Up followup day is on Thursday. Only #{channel.channel_admins_slack_mentions.or} can change that, sorry."
        )
      end

      it 'cannot set recency' do
        expect(make_message('@sup set recency 2', options)).to respond_with_slack_message(
          "Taking special care to not pair the same people more than every 12 weeks. Only #{channel.channel_admins_slack_mentions.or} can change that, sorry."
        )
      end

      it 'cannot set size' do
        expect(make_message('@sup set size 2', options)).to respond_with_slack_message(
          "Channel S'Up connects groups of 3 people. Only #{channel.channel_admins_slack_mentions.or} can change that, sorry."
        )
      end

      it 'cannot set timezone' do
        expect(make_message('@sup set tz Hawaii', options)).to respond_with_slack_message(
          "Channel S'Up timezone is #{ActiveSupport::TimeZone.new('Eastern Time (US & Canada)')}. Only #{channel.channel_admins_slack_mentions.or} can change that, sorry."
        )
      end

      it 'cannot set custom profile team field' do
        expect(make_message('@sup set team field Artsy Team', options)).to respond_with_slack_message(
          "Custom profile team field is _not set_. Only #{channel.channel_admins_slack_mentions.or} can change that, sorry."
        )
      end

      it 'cannot set message' do
        expect(make_message('@sup set message Custom message.', options)).to respond_with_slack_message(
          "Using the default S'Up message. _#{Sup::PLEASE_SUP_MESSAGE}_ Only #{channel.channel_admins_slack_mentions.or} can change that, sorry."
        )
      end

      it 'cannot set sync now' do
        expect(make_message('@sup set sync now', options)).to respond_with_slack_message(
          "Users will sync before the next round. #{channel.next_sup_at_text} Only #{channel.channel_admins_slack_mentions.or} can manually sync, sorry."
        )
      end
    end
  end

  shared_examples_for 'cannot view or change channel settings' do |options|
    ['@sup set', '@sup set opt', '@sup set opt in', '@sup unset opt', '@sup rotate api token'].each do |command|
      it "cannot #{command}" do
        expect(make_message(command, options)).to respond_with_slack_message(
          "Sorry, only members of #{channel.slack_mention}, <@#{team.activated_user_id}>, or a Slack team admin can do that."
        )
      end
    end
  end

  context 'with channel' do
    let!(:channel) { Fabricate(:channel, team:, inviter_id: 'inviter_id', channel_id: 'channel', sup_wday: Date::MONDAY, sup_followup_wday: Date::THURSDAY) }
    let(:tz) { ActiveSupport::TimeZone.new('Eastern Time (US & Canada)') }
    let(:tzs) { Time.now.in_time_zone(tz).strftime('%Z') }

    context 'in a channel' do
      context 'as an admin' do
        let(:admin) { Fabricate(:user, channel:, is_admin: true) }

        before do
          allow_any_instance_of(Channel).to receive(:is_admin?).and_return(true)
          allow(team).to receive(:find_create_or_update_user_in_channel_by_slack_id!).and_return(admin)
        end

        it_behaves_like 'can view channel settings'
        it_behaves_like 'can change channel settings'
      end

      context 'as not an admin' do
        let(:user) { Fabricate(:user, channel:, is_admin: false) }

        before do
          allow_any_instance_of(Channel).to receive(:is_admin?).and_return(false)
          allow(team).to receive(:find_create_or_update_user_in_channel_by_slack_id!).and_return(user)
        end

        it_behaves_like 'can view channel settings'
        it_behaves_like 'cannot change channel settings'
      end
    end

    context 'dm' do
      context 'a team admin' do
        before do
          allow(team).to receive(:is_admin?).and_return(true)
          allow(channel).to receive(:is_admin?).and_return(true)
        end

        it_behaves_like 'can view channel settings', { channel: 'DM', user: 'stubbed', target: '<#channel>' }
        it_behaves_like 'can change channel settings', { channel: 'DM', user: 'stubbed', target: '<#channel>' }
      end

      context 'a channel admin' do
        before do
          Fabricate(:user, channel:, user_id: 'inviter_id')
          allow(team).to receive(:is_admin?).and_return(false)
        end

        it_behaves_like 'can view channel settings', { channel: 'DM', user: 'inviter_id', target: '<#channel>' }
        it_behaves_like 'can change channel settings', { channel: 'DM', user: 'inviter_id', target: '<#channel>' }
      end

      context 'a channel user' do
        before do
          Fabricate(:user, channel:, user_id: 'member')
          allow(team).to receive(:is_admin?).and_return(false)
        end

        it_behaves_like 'can view channel settings', { channel: 'DM', user: 'member', target: '<#channel>' }
        it_behaves_like 'cannot change channel settings', { channel: 'DM', user: 'member', target: '<#channel>' }
      end

      context 'a user of the same team not a member of the channel' do
        before do
          Fabricate(:user, channel: Fabricate(:channel, team:), user_id: 'member')
          allow(team).to receive(:is_admin?).and_return(false)
        end

        it_behaves_like 'cannot view or change channel settings', { channel: 'DM', user: 'member', target: '<#channel>' }
      end

      context "not a S'Up channel" do
        it 'cannot see settings' do
          expect(make_message('@sup set', { channel: 'DM', user: 'member', target: '<#another>' })).to respond_with_slack_message(
            "Sorry, <#another> is not a S'Up channel."
          )
        end
      end
    end
  end
end
