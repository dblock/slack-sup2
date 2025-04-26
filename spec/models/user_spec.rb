require 'spec_helper'

describe User do
  describe '#sync!', vcr: { cassette_name: 'user_info' } do
    let(:channel) { Fabricate(:channel) }
    let(:user) { Fabricate(:user, channel:) }

    it 'updates user fields' do
      user.sync!
      expect(user.sync).to be false
      expect(user.last_sync_at).not_to be_nil
      expect(user.is_organizer).to be false
      expect(user.is_admin).to be true
      expect(user.is_owner).to be true
      expect(user.user_name).to eq 'username'
      expect(user.real_name).to eq 'Real Name'
      expect(user.email).to eq 'user@example.com'
    end

    context 'with team field label' do
      before do
        # avoid validation that would attempt to fetch profile
        channel.set(team_field_label_id: 'Xf6QJY0DS8')
      end

      it 'fetches custom profile information from slack', vcr: { cassette_name: 'user_profile_get' } do
        user.reload.sync!
        expect(user.custom_team_name).to eq 'Engineering'
      end
    end

    context 'admin' do
      it 'does not demote an admin' do
        user.update_attributes!(is_admin: true)
        allow_any_instance_of(Slack::Web::Client).to receive(:users_info).and_return(Hashie::Mash.new(
                                                                                       user: {
                                                                                         is_admin: false
                                                                                       }
                                                                                     ))
        user.sync!
        expect(user.reload.is_admin).to be true
      end

      it 'promotes an admin' do
        allow_any_instance_of(Slack::Web::Client).to receive(:users_info).and_return(Hashie::Mash.new(
                                                                                       user: {
                                                                                         is_admin: true
                                                                                       }
                                                                                     ))
        user.sync!
        expect(user.reload.is_admin).to be true
      end
    end
  end

  describe '#find_or_create_user!' do
    let!(:channel) { Fabricate(:channel) }

    context 'without a user' do
      context 'with opted out channel by default' do
        before do
          channel.update_attributes!(opt_in: false)
        end

        it 'creates an opted out user' do
          user = channel.find_or_create_user!('user_id')
          expect(user).not_to be_nil
          expect(user.opted_in).to be false
        end
      end

      it 'creates a user' do
        expect do
          user = channel.find_or_create_user!('user_id')
          expect(user).not_to be_nil
          expect(user.user_id).to eq 'user_id'
          expect(user.sync).to be true
        end.to change(User, :count).by(1)
      end
    end

    context 'with an existing user' do
      let!(:user) { Fabricate(:user, channel:) }

      it 'creates another user' do
        expect do
          channel.find_or_create_user!('user_id')
        end.to change(User, :count).by(1)
      end

      it 'returns the existing user' do
        expect do
          channel.find_or_create_user!(user.user_id)
        end.not_to change(User, :count)
      end
    end
  end

  describe '#last_captain_at' do
    before do
      allow_any_instance_of(Channel).to receive(:inform!)
    end

    let(:user) { Fabricate(:user) }

    it 'retuns nil when user has never been a captain' do
      expect(user.last_captain_at).to be_nil
    end

    context 'with a sup' do
      let!(:sup) { Fabricate(:sup, captain: user, created_at: 2.weeks.ago) }

      it 'returns last time user was captain' do
        expect(user.last_captain_at).to eq sup.reload.created_at
      end

      it 'returns nol for another user' do
        expect(Fabricate(:user).last_captain_at).to be_nil
      end
    end

    context 'with multiple sups' do
      let!(:sup1) { Fabricate(:sup, captain: user, created_at: 2.weeks.ago) }
      let!(:sup2) { Fabricate(:sup, captain: user, created_at: 3.weeks.ago) }

      it 'returns most recent sup' do
        expect(user.last_captain_at).to eq sup1.reload.created_at
      end
    end
  end

  describe '#suppable_user?' do
    let(:member_default_attr) do
      {
        id: 'id',
        is_bot: false,
        deleted: false,
        is_restricted: false,
        is_ultra_restricted: false,
        name: 'Forrest Gump',
        real_name: 'Real Forrest Gump',
        profile: double(email: nil, status: nil, status_text: nil)
      }
    end

    it 'is_bot' do
      expect(User.suppable_user?(Hashie::Mash.new(member_default_attr.merge(is_bot: true)))).to be false
    end

    it 'deleted' do
      expect(User.suppable_user?(Hashie::Mash.new(member_default_attr.merge(deleted: true)))).to be false
    end

    it 'restricted' do
      expect(User.suppable_user?(Hashie::Mash.new(member_default_attr.merge(is_restricted: true)))).to be false
    end

    it 'ultra_restricted' do
      expect(User.suppable_user?(Hashie::Mash.new(member_default_attr.merge(is_ultra_restricted: true)))).to be false
    end

    it 'ooo' do
      expect(User.suppable_user?(Hashie::Mash.new(member_default_attr.merge(name: 'member-name-on-ooo')))).to be false
    end

    it 'default' do
      expect(User.suppable_user?(Hashie::Mash.new(member_default_attr))).to be true
    end
  end

  describe '#parse_slack_mention' do
    it 'valid' do
      expect(User.parse_slack_mention('<@user_id>')).to eq 'user_id'
    end

    it 'invalid' do
      expect(User.parse_slack_mention('invalid')).to be_nil
    end
  end

  describe '#parse_slack_mention!' do
    it 'valid' do
      expect(User.parse_slack_mention!('<@user_id>')).to eq 'user_id'
    end

    it 'invalid' do
      expect { User.parse_slack_mention!('invalid') }.to raise_error SlackSup::Error, 'Invalid user mention invalid.'
    end
  end

  describe '#on_vacation' do
    let(:tuesday) { DateTime.parse('2017/1/3 3:00 PM EST') }

    before do
      Timecop.travel(tuesday)
    end

    it 'not on vacation' do
      expect(Fabricate(:user).on_vacation?).to be false
      expect(Fabricate(:user, opted_in: false, vacation_until: Time.now + 2.weeks).on_vacation?).to be false
      expect(Fabricate(:user, vacation_until: Time.now - 2.weeks).on_vacation?).to be false
    end

    it 'on vacation' do
      expect(Fabricate(:user, vacation_until: Time.now + 2.weeks).on_vacation?).to be true
    end

    context 'with users' do
      let(:channel) { Fabricate(:channel) }
      let!(:user1) { Fabricate(:user, channel:, vacation_until: Time.now - 2.weeks) }
      let!(:user2) { Fabricate(:user, channel:, vacation_until: Time.now + 2.weeks) }
      let!(:user3_opted_out) { Fabricate(:user, channel:, opted_in: false, vacation_until: Time.now) }
      let!(:user4_disabled) { Fabricate(:user, channel:, enabled: false, vacation_until: Time.now) }

      it 'returns vacationing users' do
        expect(channel.users.on_vacation).to eq [user2]
      end

      it 'does not freeze time' do
        expect(channel.users.on_vacation).to eq [user2]

        Timecop.travel(Time.now - 3.weeks) do
          expect(channel.users.on_vacation).to eq [user1, user2]
        end

        Timecop.travel(Time.now + 3.weeks) do
          expect(channel.users.on_vacation).to eq []
        end
      end
    end
  end
end
