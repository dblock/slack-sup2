require 'spec_helper'

describe Team do
  describe '#find_create_or_update_channel_by_channel_id!' do
    let(:team) { Fabricate(:team) }

    before do
      allow(team.slack_client).to receive(:conversations_info)
    end

    it 'creates a new channel' do
      expect do
        channel = team.find_create_or_update_channel_by_channel_id!('C123', 'U123')
        expect(channel.channel_id).to eq 'C123'
        expect(channel.inviter_id).to eq 'U123'
      end.to change(Channel, :count).by(1)
    end

    it 'does not create a new channel for DMs' do
      expect do
        channel = team.find_create_or_update_channel_by_channel_id!('D123', 'U123')
        expect(channel).to be_nil
      end.not_to change(Channel, :count)
    end

    context 'with a sup' do
      before do
        allow_any_instance_of(Channel).to receive(:inform!)
      end

      let!(:sup) { Fabricate(:sup, conversation_id: 'C123') }

      it 'does not create a new channel over a sup' do
        expect do
          channel = team.find_create_or_update_channel_by_channel_id!(sup.conversation_id, 'U123')
          expect(channel).to be_nil
        end.not_to change(Channel, :count)
      end
    end

    it 'does not create a new IM channel' do
      expect do
        expect(team.slack_client).to receive(:conversations_info).and_return(Hashie::Mash.new(
                                                                               channel: {
                                                                                 is_im: true
                                                                               }
                                                                             ))
        channel = team.find_create_or_update_channel_by_channel_id!('C1234', 'U123')
        expect(channel).to be_nil
      end.not_to change(Channel, :count)
    end

    it 'does not create a new MPIM channel' do
      expect do
        expect(team.slack_client).to receive(:conversations_info).and_return(Hashie::Mash.new(
                                                                               channel: {
                                                                                 is_mpim: true
                                                                               }
                                                                             ))
        channel = team.find_create_or_update_channel_by_channel_id!('C1234', 'U123')
        expect(channel).to be_nil
      end.not_to change(Channel, :count)
    end

    context 'with an existing channel' do
      let!(:channel) { Fabricate(:channel, team:) }

      it 'reuses an existing channel' do
        expect do
          existing_channel = team.find_create_or_update_channel_by_channel_id!(channel.channel_id, 'U123')
          expect(existing_channel).to eq channel
        end.not_to change(Channel, :count)
      end
    end
  end

  describe '#find_create_or_update_user_in_channel_by_slack_id!' do
    let(:team) { Fabricate(:team) }

    before do
      allow(team.slack_client).to receive(:conversations_info)
    end

    it 'creates a new channel and user' do
      expect do
        expect do
          user = team.find_create_or_update_user_in_channel_by_slack_id!('C123', 'U123')
          expect(user.user_id).to eq 'U123'
          expect(user.channel.channel_id).to eq 'C123'
        end.to change(Channel, :count).by(1)
      end.to change(User, :count).by(1)
    end

    it 'does not create a new channel or user for a DM' do
      expect do
        expect do
          user_id = team.find_create_or_update_user_in_channel_by_slack_id!('D123', 'U123')
          expect(user_id).to eq 'U123'
        end.not_to change(Channel, :count)
      end.not_to change(User, :count)
    end

    context 'with an existing channel' do
      let!(:channel) { Fabricate(:channel, team:) }

      it 'reuses an existing team and creates a new user' do
        expect do
          expect do
            user = team.find_create_or_update_user_in_channel_by_slack_id!(channel.channel_id, 'U123')
            expect(user.user_id).to eq 'U123'
          end.not_to change(Channel, :count)
        end.to change(User, :count).by(1)
      end

      context 'with an existing team and user' do
        let!(:user) { Fabricate(:user, channel:) }

        it 'reuses an existing channel and creates a new user' do
          expect do
            expect do
              found_user = team.find_create_or_update_user_in_channel_by_slack_id!(channel.channel_id, user.user_id)
              expect(found_user.user_id).to eq user.user_id
            end.not_to change(Channel, :count)
          end.not_to change(User, :count)
        end
      end
    end
  end

  describe '#join_channel!' do
    let!(:team) { Fabricate(:team) }

    it 'creates a new channel' do
      expect do
        channel = team.join_channel!('C123', 'U123')
        expect(channel).not_to be_nil
        expect(channel.channel_id).to eq 'C123'
        expect(channel.inviter_id).to eq 'U123'
        expect(channel.sync).to be true
        expect(channel.last_sync_at).to be_nil
      end.to change(Channel, :count).by(1)
    end

    context 'with a previously joined team' do
      let(:channel) { team.join_channel!('C123', 'U123') }

      context 'after leaving a team' do
        before do
          team.leave_channel!(channel.channel_id)
        end

        context 'after rejoining the channel' do
          let!(:rejoined_channel) { team.join_channel!(channel.channel_id, 'U456') }

          it 're-enables channel' do
            rejoined_channel.reload
            expect(rejoined_channel.enabled).to be true
            expect(rejoined_channel.inviter_id).to eq 'U456'
            expect(rejoined_channel.sync).to be true
            expect(rejoined_channel.last_sync_at).to be_nil
          end
        end
      end
    end

    context 'with an existing channel' do
      let!(:channel) { Fabricate(:channel, team:) }

      it 'creates a new channel' do
        expect do
          channel = team.join_channel!('C123', 'U123')
          expect(channel).not_to be_nil
          expect(channel.channel_id).to eq 'C123'
          expect(channel.inviter_id).to eq 'U123'
        end.to change(Channel, :count).by(1)
      end

      it 'creates a new channel for a different team' do
        expect do
          team2 = Fabricate(:team)
          channel2 = team2.join_channel!(channel.channel_id, 'U123')
          expect(channel2).not_to be_nil
          expect(channel2.team).to eq team2
          expect(channel2.inviter_id).to eq 'U123'
        end.to change(Channel, :count).by(1)
      end

      it 'updates an existing team' do
        expect do
          channel2 = team.join_channel!(channel.channel_id, 'U123')
          expect(channel2).not_to be_nil
          expect(channel2).to eq channel
          expect(channel2.team).to eq team
          expect(channel2.inviter_id).to eq 'U123'
        end.not_to change(Channel, :count)
      end
    end
  end

  describe '#leave_channel!' do
    let(:team) { Fabricate(:team) }

    it 'ignores a team the bot is not a member of' do
      expect do
        expect(team.leave_channel!('C123')).to be false
      end.not_to change(Channel, :count)
    end

    context 'with an existing team' do
      let!(:channel) { Fabricate(:channel, team:) }

      context 'after leaving a team' do
        before do
          team.leave_channel!(channel.channel_id)
        end

        it 'disables channel' do
          channel.reload
          expect(channel.enabled).to be false
          expect(channel.sync).to be false
        end
      end

      it 'can leave an existing team twice' do
        expect do
          2.times { expect(team.leave_channel!(channel.channel_id)).to eq channel }
        end.not_to change(Channel, :count)
      end

      it 'does not leave team for the wrong team' do
        team2 = Fabricate(:team)
        expect(team2.leave_channel!(channel.channel_id)).to be false
      end
    end
  end

  describe '#purge!' do
    let!(:active_team) { Fabricate(:team) }
    let!(:inactive_team) { Fabricate(:team, active: false) }
    let!(:inactive_team_a_week_ago) { Fabricate(:team, updated_at: 1.week.ago, active: false) }
    let!(:inactive_team_three_weeks_ago) { Fabricate(:team, updated_at: 3.weeks.ago, active: false) }
    let!(:inactive_team_a_month_ago) { Fabricate(:team, updated_at: 1.month.ago, active: false) }

    it 'destroys teams inactive for two weeks' do
      expect do
        Team.purge!
      end.to change(Team, :count).by(-2)
      expect(Team.find(active_team.id)).to eq active_team
      expect(Team.find(inactive_team.id)).to eq inactive_team
      expect(Team.find(inactive_team_a_week_ago.id)).to eq inactive_team_a_week_ago
      expect(Team.find(inactive_team_three_weeks_ago.id)).to be_nil
      expect(Team.find(inactive_team_a_month_ago.id)).to be_nil
    end
  end

  describe '#asleep?' do
    context 'default' do
      let(:team) { Fabricate(:team, created_at: Time.now.utc) }

      it 'false' do
        expect(team.asleep?).to be false
      end
    end

    context 'team created three weeks ago' do
      let(:team) { Fabricate(:team, created_at: 3.weeks.ago) }

      it 'is asleep' do
        expect(team.asleep?).to be true
      end
    end

    context 'team created two weeks ago and subscribed' do
      let(:team) { Fabricate(:team, created_at: 2.weeks.ago, subscribed: true) }

      before do
        allow(team).to receive(:inform_subscribed_changed!)
        team.update_attributes!(subscribed: true)
      end

      it 'is not asleep' do
        expect(team.asleep?).to be false
      end
    end

    context 'team created over three weeks ago' do
      let(:team) { Fabricate(:team, created_at: 3.weeks.ago - 1.day) }

      it 'is asleep' do
        expect(team.asleep?).to be true
      end
    end

    context 'team created over two weeks ago and subscribed' do
      let(:team) { Fabricate(:team, created_at: 2.weeks.ago - 1.day, subscribed: true) }

      it 'is not asleep' do
        expect(team.asleep?).to be false
      end
    end
  end

  describe '#api_url' do
    let!(:team) { Fabricate(:team) }

    it 'sets the API url' do
      expect(team.api_url).to eq "https://sup2.playplay.io/api/teams/#{team._id}"
    end
  end

  describe '#is_admin?' do
    let!(:team) { Fabricate(:team) }

    it 'activated_user_id' do
      expect(team.is_admin?(team.activated_user_id)).to be true
    end

    it 'is_admin or is_owner', vcr: { cassette_name: 'user_info' } do
      expect(team.is_admin?('username')).to be true
    end

    it 'is_admin' do
      allow_any_instance_of(Slack::Web::Client).to receive(:users_info).and_return(
        Hashie::Mash.new(user: { is_admin: true, is_owner: false })
      )
      expect(team.is_admin?('username')).to be true
    end

    it 'is_owner' do
      allow_any_instance_of(Slack::Web::Client).to receive(:users_info).and_return(
        Hashie::Mash.new(user: { is_admin: false, is_owner: true })
      )
      expect(team.is_admin?('username')).to be true
    end

    it 'invalid' do
      allow_any_instance_of(Slack::Web::Client).to receive(:users_info).and_return(
        Hashie::Mash.new(user: { is_admin: false, is_owner: false })
      )
      expect(team.is_admin?('username')).to be false
    end
  end

  pending '#enabled_channels_text'
  context 'update_cc_url' do
    let(:team) { Fabricate(:team) }

    it 'generates a new token every time' do
      expect(team.update_cc_url).to include "?team_id=#{team.team_id}"
      expect(team.update_cc_url).not_to eq team.update_cc_url
    end
  end

  describe '#stats' do
    let(:team) { Fabricate(:team) }

    it 'generates stats' do
      expect(team.stats).to be_a TeamStats
      expect(team.stats_s).to eq "Team S'Up is not in any channels. Invite S'Up to a channel with some users to get started!"
    end
  end

  describe '#export' do
    let(:team) { Fabricate(:team) }

    include_context 'uses temp dir'

    before do
      team.export!(tmp)
    end

    %w[channels rounds stats sups team users].each do |csv|
      it "creates #{csv}.csv" do
        expect(File.exist?(File.join(tmp, "#{csv}.csv"))).to be true
      end
    end

    context 'team.csv' do
      let(:csv) { CSV.read(File.join(tmp, 'team.csv'), headers: true) }

      it 'generates teams.csv' do
        expect(csv.headers).to eq(%w[id team_id name domain active subscribed subscribed_at created_at updated_at])
        expect(csv[0]['team_id']).to eq(team.team_id)
      end
    end
  end

  describe '#export_zip!' do
    let(:team) { Fabricate(:team) }
    let!(:zip) { team.export_zip!(tmp) }

    include_context 'uses temp dir'

    it 'exists' do
      expect(File.exist?(zip)).to be true
      expect(File.size(zip)).not_to eq 0
    end
  end

  describe '#max_rounds_count' do
    let(:team) { Fabricate(:team) }

    it 'returns 0 without rounds' do
      expect(team.max_rounds_count).to eq(0)
    end

    context 'with two channels' do
      let!(:channel1) { Fabricate(:channel, team: team) }
      let!(:channel2) { Fabricate(:channel, team: team) }
      let!(:channel3) { Fabricate(:channel, team: team) }

      before do
        allow_any_instance_of(Channel).to receive(:sync!)
        allow_any_instance_of(Channel).to receive(:inform!)
        2.times { channel1.sup! }
        channel2.sup!
      end

      it 'returns max count' do
        expect(team.max_rounds_count).to eq 2
      end
    end
  end
end
