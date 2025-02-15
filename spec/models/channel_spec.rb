require 'spec_helper'

describe Channel do
  context 'channel_admins' do
    let!(:channel) { Fabricate(:channel) }

    it 'has no inviter' do
      expect(channel.channel_admins).to eq([])
    end

    context 'with an inviter' do
      let!(:user) { Fabricate(:user, channel:) }

      before do
        channel.update_attributes!(inviter_id: user.user_id)
      end

      it 'has an admin' do
        expect(channel.channel_admins).to eq([user])
        expect(channel.channel_admins_slack_mentions).to eq([user.slack_mention])
      end

      context 'with another admin' do
        let!(:another) { Fabricate(:user, channel:, is_admin: true) }

        it 'has two admins' do
          expect(channel.channel_admins.to_a.sort).to eq([user, another].sort)
          expect(channel.channel_admins_slack_mentions).to eq([user.slack_mention, another.slack_mention])
        end
      end

      context 'with an admin in another channel' do
        let!(:another) { Fabricate(:user, channel: Fabricate(:channel), is_admin: true) }

        it 'has one admin' do
          expect(channel.channel_admins).to eq([user])
          expect(channel.channel_admins_slack_mentions).to eq([user.slack_mention])
        end
      end

      context 'with a disabled admin' do
        let!(:another) { Fabricate(:user, channel:, enabled: false, is_admin: true) }

        it 'has one admin' do
          expect(channel.channel_admins).to eq([user])
          expect(channel.channel_admins_slack_mentions).to eq([user.slack_mention])
        end
      end

      context 'with a team admin' do
        let!(:another) { Fabricate(:user, channel:, is_admin: false) }

        before do
          channel.team.update_attributes!(activated_user_id: another.user_id)
        end

        it 'has two admins' do
          expect(channel.channel_admins.to_a.sort).to eq([user, another].sort)
          expect(channel.channel_admins_slack_mentions).to eq([user.slack_mention, another.slack_mention])
        end
      end

      context 'with a different team admin' do
        let!(:team_admin) { Fabricate(:user, channel:, is_admin: false) }
        let!(:another) { Fabricate(:user, channel:, is_admin: true) }

        before do
          channel.team.update_attributes!(activated_user_id: team_admin.user_id)
        end

        it 'has three admins' do
          expect(channel.channel_admins.to_a.sort).to eq([user, team_admin, another].sort)
        end
      end

      context 'with another owner' do
        let!(:another) { Fabricate(:user, channel:, is_owner: true) }

        it 'has two admins' do
          expect(channel.channel_admins.to_a.sort).to eq([user, another].sort)
          expect(channel.channel_admins_slack_mentions).to eq([user.slack_mention, another.slack_mention])
        end
      end
    end
  end

  context 'days of week' do
    {
      DateTime.parse('2017/1/2 3:00 PM EST').utc => { wday: Date::TUESDAY, followup_wday: Date::THURSDAY },
      DateTime.parse('2017/1/3 3:00 PM EST').utc => { wday: Date::WEDNESDAY, followup_wday: Date::FRIDAY },
      DateTime.parse('2017/1/4 3:00 PM EST').utc => { wday: Date::THURSDAY, followup_wday: Date::TUESDAY },
      DateTime.parse('2017/1/5 3:00 PM EST').utc => { wday: Date::FRIDAY, followup_wday: Date::TUESDAY },
      DateTime.parse('2017/1/6 3:00 PM EST').utc => { wday: Date::MONDAY, followup_wday: Date::THURSDAY },
      DateTime.parse('2017/1/7 3:00 PM EST').utc => { wday: Date::MONDAY, followup_wday: Date::THURSDAY },
      DateTime.parse('2017/1/8 3:00 PM EST').utc => { wday: Date::MONDAY, followup_wday: Date::THURSDAY }
    }.each_pair do |dt, expectations|
      context "created on #{Date::DAYNAMES[dt.wday]}" do
        before do
          Timecop.travel(dt)
        end

        let(:channel) { Fabricate(:channel) }

        it "sets sup to #{Date::DAYNAMES[expectations[:wday]]}" do
          expect(channel.sup_wday).to eq expectations[:wday]
        end

        it "sets reminder to #{Date::DAYNAMES[expectations[:followup_wday]]}" do
          expect(channel.sup_followup_wday).to eq expectations[:followup_wday]
        end
      end
    end
  end

  context 'sync!' do
    let!(:channel) { Fabricate(:channel) }
    let(:member_default_attr) do
      {
        is_bot: false,
        deleted: false,
        is_restricted: false,
        is_ultra_restricted: false,
        name: 'Forrest Gump',
        real_name: 'Real Forrest Gump',
        profile: double(email: nil, status: nil, status_text: nil)
      }
    end

    context 'with mixed users' do
      let(:bot_member) { Hashie::Mash.new(member_default_attr.merge(id: 'bot-user', is_bot: true)) }
      let(:deleted_member) { Hashie::Mash.new(member_default_attr.merge(id: 'deleted-user', deleted: true)) }
      let(:restricted_member) { Hashie::Mash.new(member_default_attr.merge(id: 'restricted-user', is_restricted: true)) }
      let(:ultra_restricted_member) { Hashie::Mash.new(member_default_attr.merge(id: 'ult-rest-user', is_ultra_restricted: true)) }
      let(:ooo_member) { Hashie::Mash.new(member_default_attr.merge(id: 'ooo-user', name: 'member-name-on-ooo')) }
      let(:available_member) { Hashie::Mash.new(member_default_attr.merge(id: 'avaialable-user')) }
      let(:members) do
        [bot_member, deleted_member, restricted_member, ultra_restricted_member, ooo_member, available_member]
      end

      before do
        allow_any_instance_of(Slack::Web::Client).to receive(:conversations_members).and_yield(
          Hashie::Mash.new(members: members.map(&:id))
        )
        members.each do |member|
          allow_any_instance_of(Slack::Web::Client).to receive(:users_info)
            .with(user: member.id).and_return(Hashie::Mash.new(user: member))
        end
      end

      it 'adds new users' do
        expect { channel.sync! }.to change(User, :count).by(1)
        new_user = User.last
        expect(new_user.user_id).to eq 'avaialable-user'
        expect(new_user.opted_in).to be true
        expect(new_user.user_name).to eq 'Forrest Gump'
      end

      it 'adds new opted out users' do
        channel.opt_in = false
        expect { channel.sync! }.to change(User, :count).by(1)
        new_user = User.last
        expect(new_user.opted_in).to be false
      end

      it 'disables dead users' do
        available_user = Fabricate(:user, channel:, user_id: available_member.id, enabled: true)
        to_be_disabled_users = [deleted_member, restricted_member, ultra_restricted_member, ooo_member].map do |member|
          Fabricate(:user, channel:, user_id: member.id, enabled: true)
        end
        expect { channel.sync! }.not_to change(User, :count)
        expect(to_be_disabled_users.map(&:reload).map(&:enabled)).to eq [false] * 4
        expect(available_user.reload.enabled).to be true
      end

      it 'reactivates users that are back' do
        disabled_user = Fabricate(:user, channel:, enabled: false, user_id: available_member.id)
        expect { channel.sync! }.not_to change(User, :count)
        expect(disabled_user.reload.enabled).to be true
      end

      pending 'fetches user custom channel information'
    end

    context 'with slack users' do
      let(:members) { [] }

      before do
        allow_any_instance_of(Slack::Web::Client).to receive(:conversations_members).and_yield(Hashie::Mash.new(members:))
        members.each do |member|
          allow_any_instance_of(Slack::Web::Client).to receive(:users_info)
            .with(user: member).and_return(
              Hashie::Mash.new(user: member_default_attr.merge(id: member))
            )
        end
      end

      context 'with a slack user' do
        let(:members) { ['M1'] }

        it 'creates a new member' do
          expect do
            channel.sync!
          end.to change(User, :count).by(1)
        end
      end

      context 'with two slack users' do
        let(:members) { %w[M1 M2] }

        it 'creates two new users' do
          expect do
            channel.sync!
          end.to change(User, :count).by(2)
          expect(channel.users.count).to eq 2
          expect(channel.users.all?(&:enabled)).to be true
        end
      end

      context 'with an existing user' do
        let(:members) { %w[M1 M2] }

        before do
          Fabricate(:user, channel:, user_id: 'M1')
        end

        it 'creates one new member' do
          expect do
            channel.sync!
          end.to change(User, :count).by(1)
          expect(channel.users.count).to eq 2
          expect(channel.users.all?(&:enabled)).to be true
        end
      end

      context 'with an existing user' do
        let(:members) { ['M2'] }

        before do
          Fabricate(:user, channel:, user_id: 'M1')
        end

        it 'removes an inactive user' do
          expect do
            channel.sync!
          end.to change(User, :count).by(1)
          expect(channel.users.count).to eq 2
          expect(channel.users.where(user_id: 'M1').first.enabled).to be false
          expect(channel.users.where(user_id: 'M2').first.enabled).to be true
        end
      end

      context 'with an existing disabled user' do
        let(:members) { ['M1'] }
        let!(:member) { Fabricate(:user, channel:, user_id: 'M1', enabled: false) }

        it 're-enables it' do
          old_updated_at = member.updated_at
          expect do
            channel.sync!
          end.not_to change(User, :count)
          expect(member.reload.enabled).to be true
          expect(member.updated_at).not_to eq old_updated_at
        end
      end

      context 'with two teams' do
        let(:members) { %w[M1 M2] }

        it 'creates two new members' do
          expect do
            Fabricate(:channel, team: Fabricate(:team)).sync!
            channel.sync!
          end.to change(User, :count).by(4)
          expect(channel.users.count).to eq 2
        end
      end
    end
  end

  context 'channel sup on monday 3pm' do
    let(:tz) { 'Eastern Time (US & Canada)' }
    let(:channel) { Fabricate(:channel, sup_wday: Date::MONDAY, sup_tz: tz) }
    let(:monday) { DateTime.parse('2017/1/2 3:00 PM EST').utc }

    before do
      Timecop.travel(monday)
    end

    context 'sup?' do
      it 'sups' do
        expect(channel.sup?).to be true
      end

      it 'in a different timezone' do
        channel.update_attributes!(sup_tz: 'Samoa') # Samoa is UTC-11, at 3pm in EST it's Tuesday 10AM
        expect(channel.sup?).to be false
      end
    end

    context 'next_sup_at' do
      it 'today' do
        expect(channel.next_sup_at).to eq DateTime.parse('2017/1/2 9:00 AM EST')
      end
    end
  end

  context 'channel sup on monday before 9am' do
    let(:tz) { 'Eastern Time (US & Canada)' }
    let(:channel) { Fabricate(:channel, sup_wday: Date::MONDAY, sup_tz: tz) }
    let(:monday) { DateTime.parse('2017/1/2 8:00 AM EST').utc }

    before do
      Timecop.travel(monday)
    end

    it 'does not sup' do
      expect(channel.sup?).to be false
    end

    context 'next_sup_at' do
      it 'today' do
        expect(channel.next_sup_at).to eq DateTime.parse('2017/1/2 9:00 AM EST')
      end
    end
  end

  context 'with a custom sup_time_of_day' do
    let(:tz) { 'Eastern Time (US & Canada)' }
    let(:channel) { Fabricate(:channel, sup_wday: Date::MONDAY, sup_time_of_day: 7 * 60 * 60, sup_tz: tz) }
    let(:monday) { DateTime.parse('2017/1/2 8:00 AM EST').utc }

    before do
      Timecop.travel(monday)
    end

    context 'sup?' do
      it 'sups' do
        expect(channel.sup?).to be true
      end
    end

    context 'next_sup_at' do
      it 'overdue, one hour ago' do
        expect(channel.next_sup_at).to eq DateTime.parse('2017/1/2 7:00 AM EST')
      end
    end
  end

  context 'channel' do
    let(:tz) { 'Eastern Time (US & Canada)' }
    let(:t_in_time_zone) { Time.now.utc.in_time_zone(tz) }
    let(:wday) { t_in_time_zone.wday }
    let(:beginning_of_day) { t_in_time_zone.beginning_of_day }
    let(:eight_am) { 8 * 60 * 60 }
    let(:channel) { Fabricate(:channel, sup_wday: wday, sup_time_of_day: eight_am, sup_tz: tz) }
    let(:on_time_sup) { beginning_of_day + channel.sup_time_of_day }

    describe '#sup!' do
      before do
        allow(channel).to receive(:sync!)
        allow(channel).to receive(:inform!)
      end

      it 'creates a round for a channel' do
        expect do
          channel.sup!
        end.to change(Round, :count).by(1)
        round = Round.first
        expect(round.channel).to eq(channel)
        expect(channel).to have_received(:inform!).with(
          "Hi! Unfortunately, I couldn't find any users to pair in a new S'Up. Invite some more users to this channel!"
        )
      end
    end

    describe '#ask!' do
      it 'works without rounds' do
        expect { channel.ask! }.not_to raise_error
      end

      context 'with a round' do
        before do
          allow(channel).to receive(:sync!)
          allow(channel).to receive(:inform!)
          channel.sup!
        end

        let(:last_round) { channel.last_round }

        it 'skips last round' do
          allow_any_instance_of(Round).to receive(:ask?).and_return(false)
          expect_any_instance_of(Round).not_to receive(:ask!)
          channel.ask!
        end

        it 'checks against last round' do
          allow_any_instance_of(Round).to receive(:ask?).and_return(true)
          expect_any_instance_of(Round).to receive(:ask!).once
          channel.ask!
        end
      end
    end

    describe '#sup?' do
      before do
        allow(channel).to receive(:sync!)
        allow(channel).to receive(:inform!)
        Timecop.travel(on_time_sup)
      end

      context 'without rounds' do
        it 'is true' do
          expect(channel.sup?).to be true
        end
      end

      context 'with a round on time' do
        before do
          channel.sup!
        end

        it 'is false' do
          expect(channel.sup?).to be false
        end

        context 'after less than a week' do
          before do
            Timecop.travel(on_time_sup + 6.days)
          end

          it 'is false' do
            expect(channel.sup?).to be false
          end
        end

        context 'after more than a week' do
          before do
            Timecop.travel(on_time_sup + 7.days)
          end

          it 'is true' do
            expect(channel.sup?).to be true
          end

          context 'and another round' do
            before do
              channel.sup!
            end

            it 'is false' do
              expect(channel.sup?).to be false
            end
          end
        end

        context 'with a custom sup_every_n_weeks' do
          before do
            channel.update_attributes!(sup_every_n_weeks: 2)
          end

          context 'after more than a week' do
            before do
              Timecop.travel(on_time_sup + 7.days)
            end

            it 'is true' do
              expect(channel.sup?).to be false
            end
          end

          context 'after more than two weeks' do
            before do
              Timecop.travel(on_time_sup + 14.days)
            end

            it 'is true' do
              expect(channel.sup?).to be true
            end
          end
        end

        context 'after more than a week on the wrong day of the week' do
          before do
            Timecop.travel(on_time_sup + 8.days)
          end

          it 'is false' do
            expect(channel.sup?).to be false
          end
        end
      end

      context 'with a round delayed by an hour' do
        before do
          Timecop.freeze(on_time_sup + 1.hour) do
            channel.sup!
          end
        end

        it 'is false' do
          expect(channel.sup?).to be false
        end

        context 'after less than a week' do
          before do
            Timecop.travel(on_time_sup + 6.days)
          end

          it 'is false' do
            expect(channel.sup?).to be false
          end
        end

        context 'before sup time a week later' do
          before do
            Timecop.travel(on_time_sup + 7.days - 1.hour)
          end

          it 'is false' do
            expect(channel.sup?).to be false
          end
        end

        context 'on time a week later' do
          before do
            Timecop.travel(on_time_sup + 7.days)
          end

          it 'is true' do
            expect(channel.sup?).to be true
          end
        end

        context 'after more than a week' do
          before do
            Timecop.travel(on_time_sup + 7.days + 1.hour)
          end

          it 'is true' do
            expect(channel.sup?).to be true
          end

          context 'and another round' do
            before do
              channel.sup!
            end

            it 'is false' do
              expect(channel.sup?).to be false
            end
          end
        end

        context 'with a custom sup_every_n_weeks' do
          before do
            channel.update_attributes!(sup_every_n_weeks: 2)
          end

          context 'after more than a week' do
            before do
              Timecop.travel(on_time_sup + 7.days)
            end

            it 'is true' do
              expect(channel.sup?).to be false
            end
          end

          context 'after more than two weeks' do
            before do
              Timecop.travel(on_time_sup + 14.days)
            end

            it 'is true' do
              expect(channel.sup?).to be true
            end
          end
        end

        context 'after more than a week on the wrong day of the week' do
          before do
            Timecop.travel(on_time_sup + 8.days)
          end

          it 'is false' do
            expect(channel.sup?).to be false
          end
        end
      end
    end
  end

  describe '#find_user_by_slack_mention!' do
    let(:channel) { Fabricate(:channel) }
    let(:user) { Fabricate(:user, channel:) }

    it 'finds by slack id' do
      expect(channel.find_user_by_slack_mention!("<@#{user.user_id}>")).to eq user
    end

    it 'finds by username' do
      expect(channel.find_user_by_slack_mention!(user.user_name)).to eq user
    end

    it 'finds by username is case-insensitive' do
      expect(channel.find_user_by_slack_mention!(user.user_name.capitalize)).to eq user
    end

    it 'creates a new user when ID is known' do
      expect do
        channel.find_user_by_slack_mention!('<@nobody>')
      end.to change(User, :count).by(1)
    end

    it 'requires a known user' do
      expect do
        channel.find_user_by_slack_mention!('nobody')
      end.to raise_error SlackSup::Error, "I don't know who nobody is!"
    end
  end

  describe '#api_url' do
    let(:channel) { Fabricate(:channel) }

    it 'sets the API url' do
      expect(channel.api_url).to eq "https://sup2.playplay.io/api/channels/#{channel._id}"
    end
  end

  describe '#short_lived_token' do
    let(:channel) { Fabricate(:channel) }
    let!(:token) { channel.short_lived_token }

    it 'creates a new token every time' do
      expect(channel.short_lived_token).not_to eq token
    end

    it 'validates the token' do
      expect(channel.short_lived_token_valid?(token)).to be true
    end

    it 'does not validate an incorrect token' do
      expect(channel.short_lived_token_valid?('invalid')).to be false
    end

    it 'does not validate an expired token' do
      Timecop.travel(Time.now + 1.hour)
      expect(channel.short_lived_token_valid?(token)).to be false
    end
  end

  describe '#parse_slack_mention' do
    it 'valid' do
      expect(Channel.parse_slack_mention('<#channel_id>')).to eq 'channel_id'
    end

    it 'valid with name' do
      expect(Channel.parse_slack_mention('<#channel_id|name>')).to eq 'channel_id'
    end

    it 'invalid' do
      expect(Channel.parse_slack_mention('invalid')).to be_nil
    end
  end

  describe '#parse_slack_mention!' do
    it 'valid' do
      expect(Channel.parse_slack_mention!('<#channel_id>')).to eq 'channel_id'
    end

    it 'invalid' do
      expect { Channel.parse_slack_mention!('invalid') }.to raise_error SlackSup::Error, 'Invalid channel mention invalid.'
    end
  end

  describe '#stats' do
    let(:channel) { Fabricate(:channel, sup_wday: Date::MONDAY, sup_followup_wday: Date::THURSDAY) }

    it 'generates stats' do
      expect(channel.stats).to be_a ChannelStats
      expect(channel.stats_s).to eq [
        "Channel S'Up connects groups of 3 people on Monday after 9:00 AM every week in #{channel.slack_mention}.",
        "There's only 1 user in this channel. Invite some more users to this channel to get started!"
      ].join("\n")
    end
  end

  describe '#export' do
    let(:channel) { Fabricate(:channel) }

    include_context 'uses temp dir'

    before do
      allow(channel).to receive(:sync!)
      allow(channel).to receive(:inform!)
    end

    context 'with one sup' do
      before do
        channel.sup!
        channel.export!(tmp)
      end

      %w[channel rounds sups stats users].each do |csv|
        it "creates #{csv}.csv" do
          expect(File.exist?(File.join(tmp, "#{csv}.csv"))).to be true
        end
      end

      it 'creates rounds subfolders' do
        expect(Dir.exist?(File.join(tmp, 'rounds'))).to be true
        expect(File.exist?(File.join(tmp, 'rounds', channel.rounds.first.ran_at.strftime('%F'), 'round.csv'))).to be true
      end

      context 'channel.csv' do
        let(:csv) { CSV.read(File.join(tmp, 'channel.csv'), headers: true) }

        it 'generates csv' do
          expect(csv.headers).to eq(
            %w[
              id
              enabled
              channel_id
              created_at
              updated_at
              sup_wday
              sup_followup_wday
              sup_day
              sup_tz
              sup_time_of_day
              sup_time_of_day_s
              sup_every_n_weeks
              sup_size
            ]
          )
          row = csv[0]
          expect(row['channel_id']).to eq channel.channel_id
        end
      end
    end

    context 'with 3 sups' do
      context 'with one sup' do
        before do
          3.times do |i|
            Timecop.travel(Time.now + i.days)
            channel.sup!
          end
        end

        context 'default export' do
          before do
            channel.export!(tmp)
          end

          %w[channel rounds sups stats users].each do |csv|
            it "creates #{csv}.csv" do
              expect(File.exist?(File.join(tmp, "#{csv}.csv"))).to be true
            end
          end

          it 'creates rounds subfolders' do
            expect(Dir.exist?(File.join(tmp, 'rounds'))).to be true
            channel.rounds.each do |round|
              expect(File.exist?(File.join(tmp, 'rounds', round.ran_at.strftime('%F'), 'round.csv'))).to be true
            end
          end
        end

        context 'export with max_rounds_count' do
          before do
            channel.export!(tmp, { max_rounds_count: 1 })
          end

          %w[channel rounds sups stats users].each do |csv|
            it "creates #{csv}.csv" do
              expect(File.exist?(File.join(tmp, "#{csv}.csv"))).to be true
            end
          end

          it 'creates limits the number of rounds exported' do
            expect(Dir.exist?(File.join(tmp, 'rounds'))).to be true
            rounds = channel.rounds.desc(:ran_at)
            expect(File.exist?(File.join(tmp, 'rounds', rounds[0].ran_at.strftime('%F'), 'round.csv'))).to be true
            expect(File.exist?(File.join(tmp, 'rounds', rounds[1].ran_at.strftime('%F'), 'round.csv'))).to be false
            expect(File.exist?(File.join(tmp, 'rounds', rounds[2].ran_at.strftime('%F'), 'round.csv'))).to be false
          end
        end
      end
    end
  end

  describe '#export_zip!' do
    let(:channel) { Fabricate(:channel) }

    include_context 'uses temp dir'

    before do
      allow(channel).to receive(:sync!)
      allow(channel).to receive(:inform!)
      channel.sup!
      channel.export!(tmp)
    end

    context 'zip' do
      let!(:zip) { channel.export_zip!(tmp) }

      it 'exists' do
        expect(File.exist?(zip)).to be true
        expect(File.size(zip)).not_to eq 0
      end
    end
  end

  describe '#is_admin?' do
    let(:channel) { Fabricate(:channel) }

    it 'invalid' do
      allow_any_instance_of(Slack::Web::Client).to receive(:users_info).and_return(
        Hashie::Mash.new(
          user: {
            is_admin: false,
            is_owner: false
          }
        )
      )

      expect(channel.is_admin?('invalid')).to be false
    end

    it 'a team admin' do
      expect(channel.is_admin?(channel.team.activated_user_id)).to be true
    end

    context 'channel inviter' do
      let!(:channel_inviter) { Fabricate(:user, channel:, user_id: channel.inviter_id) }

      it 'by id' do
        expect(channel.is_admin?(channel.inviter_id)).to be true
      end

      it 'by user_id' do
        expect(channel.is_admin?(channel_inviter.user_id)).to be true
      end

      it 'by user' do
        expect(channel.is_admin?(channel_inviter)).to be true
      end
    end

    {
      { is_admin: false, is_owner: false } => false,
      { is_admin: true, is_owner: false } => true,
      { is_admin: false, is_owner: true } => true,
      { is_admin: true, is_owner: true } => true
    }.each_pair do |u, expected|
      context u do
        before do
          allow_any_instance_of(Slack::Web::Client).to receive(:users_info).with(
            user: 'user'
          ).and_return(
            Hashie::Mash.new(
              user: u
            )
          )
        end

        it 'correct' do
          expect(channel.is_admin?('user')).to eq expected
        end
      end
    end
  end
end
