require 'spec_helper'

describe Round do
  let(:channel) { Fabricate(:channel) }

  before do
    allow(channel).to receive(:sync!)
    allow(channel).to receive(:inform!)
    allow_any_instance_of(Sup).to receive(:dm!)
  end

  describe '#run' do
    context 'without users' do
      it 'does not generate a sup' do
        expect do
          channel.sup!
        end.not_to change(Sup, :count)
        expect(channel).to have_received(:inform!).with(
          "Hi! Unfortunately, I couldn't find any users to pair in a new S'Up. Invite some more users to this channel!"
        )
      end
    end

    context 'with one user' do
      let!(:user1) { Fabricate(:user, channel:) }

      it 'does not generate a sup' do
        expect do
          channel.sup!
        end.not_to change(Sup, :count)
        expect(channel).to have_received(:inform!).with(
          "Hi! Unfortunately, I only found 1 user to pair in a new S'Up of 3. Invite some more users to this channel, lower `@sup set size` or adjust `@sup set odd`."
        )
      end
    end

    context 'with one opted out user' do
      let!(:user1) { Fabricate(:user, channel:, opted_in: false) }

      it 'does not generate a sup' do
        expect do
          channel.sup!
        end.not_to change(Sup, :count)
        expect(channel).to have_received(:inform!).with(
          "Hi! Unfortunately, I couldn't find any opted in users to pair in a new S'Up. Invite some more users to this channel!"
        )
      end
    end

    context 'with two users' do
      let!(:user1) { Fabricate(:user, channel:) }
      let!(:user2) { Fabricate(:user, channel:) }

      context 'without odd' do
        before do
          channel.update_attributes!(sup_odd: false)
        end

        it 'does not generate a sup' do
          expect do
            channel.sup!
          end.not_to change(Sup, :count)
          expect(channel).to have_received(:inform!).with(
            "Hi! Unfortunately, I only found 2 users to pair in a new S'Up of 3. Invite some more users to this channel, lower `@sup set size` or adjust `@sup set odd`."
          )
        end
      end

      context 'with default odd' do
        it 'generates a sup' do
          expect do
            channel.sup!
          end.to change(Sup, :count).by(1)
          expect(channel).to have_received(:inform!).with(
            "Hi! I have created a new round with 1 S'Up, pairing all of 2 users."
          )
        end
      end
    end

    context 'with 12 users' do
      before do
        12.times { Fabricate(:user, channel:) }
      end

      context 'with 2 previous sups' do
        before do
          2.times { channel.sup! }
        end

        it 'is able to find a new combination' do
          expect do
            round = channel.sup!
            expect(round.sups.map(&:users).flatten.size).to eq channel.users.size
          end.to change(Sup, :count).by(4)
          expect(channel).to have_received(:inform!).with(
            "Hi! I have created a new round with 4 S'Ups, pairing all of 12 users."
          ).exactly(3).times
        end
      end
    end

    context 'with enough users' do
      let!(:user1) { Fabricate(:user, channel:) }
      let!(:user2) { Fabricate(:user, channel:) }
      let!(:user3) { Fabricate(:user, channel:) }

      it 'generates sup_size size' do
        expect do
          channel.sup!
        end.to change(Sup, :count).by(1)
        sup = Sup.first
        expect(sup.users).to eq([user1, user2, user3])
      end

      it 'updates counts' do
        expect do
          channel.sup!
        end.to change(Round, :count).by(1)
        round = Round.first
        expect(round.total_users_count).to eq 3
        expect(round.opted_in_users_count).to eq 3
        expect(round.opted_out_users_count).to eq 0
        expect(round.paired_users_count).to eq 3
        expect(round.missed_users_count).to eq 0
      end

      context 'timeout' do
        before do
          stub_const 'Round::TIMEOUT', 1
        end

        it 'times out Round::TIMEOUT' do
          allow_any_instance_of(Round).to receive(:solve).and_wrap_original do |method, *args|
            sleep Round::TIMEOUT
            method.call(*args)
          end
          round = channel.sup!
          expect(round.sups.map(&:users).flatten.size).to eq 0
        end
      end

      context 'with sup_size of 3' do
        let!(:user4) { Fabricate(:user, channel:) }
        let!(:user5) { Fabricate(:user, channel:) }
        let!(:user6) { Fabricate(:user, channel:) }
        let!(:user7) { Fabricate(:user, channel:) }
        let!(:user8) { Fabricate(:user, channel:) }
        let!(:user9) { Fabricate(:user, channel:) }
        let!(:user10) { Fabricate(:user, channel:) }

        before do
          channel.update_attributes!(sup_size: 3)
        end

        it 'generates groups of 3' do
          expect do
            round = channel.sup!
            expect(round.sups.map(&:users).flatten.size).to eq channel.users.size
          end.to change(Sup, :count).by(3)
          expect(channel).to have_received(:inform!).with(
            "Hi! I have created a new round with 3 S'Ups, pairing all of 10 users."
          )
        end

        it 'when odd users met recently' do
          first_round = channel.sup!
          expect(first_round.sups.map(&:users).flatten.size).to eq channel.users.size
          expect do
            round = channel.sup!
            expect(round.sups.map(&:users).flatten.size).to eq channel.users.size - 1
          end.to change(Sup, :count).by(3)
          expect(channel).to have_received(:inform!).with(
            "Hi! I have created a new round with 3 S'Ups, pairing 9 users. Unfortunately, I wasn't able to find a group for the remaining 1. Consider increasing the value of `@sup set weeks`, lowering the value of `@sup set recency`, or adjusting `@sup set odd`."
          )
        end

        it 'when new users have not met recently' do
          first_round = channel.sup!
          expect(first_round.sups.map(&:users).flatten.size).to eq channel.users.size
          3.times { Fabricate(:user, channel:) } # 3 more users so we can have at least 1 non-met group
          expect do
            round = channel.sup!
            expect(round.sups.map(&:users).flatten.size).to eq channel.users.size
          end.to change(Sup, :count).by(4)
          expect(channel).to have_received(:inform!).with(
            "Hi! I have created a new round with 4 S'Ups, pairing all of 13 users."
          )
        end
      end

      context 'with sup_size of 2' do
        let!(:user4) { Fabricate(:user, channel:) }
        let!(:user5) { Fabricate(:user, channel:) }
        let!(:user6) { Fabricate(:user, channel:) }

        before do
          channel.update_attributes!(sup_size: 2)
        end

        it 'generates pairs' do
          expect do
            channel.sup!
          end.to change(Sup, :count).by(3)
          expect(Sup.all.all? { |sup| sup.users.count == 2 })
          expect(channel).to have_received(:inform!).with(
            "Hi! I have created a new round with 3 S'Ups, pairing all of 6 users."
          )
        end
      end

      context 'with one extra user' do
        let!(:user4) { Fabricate(:user, channel:) }

        it 'adds the user to an existing sup' do
          round = channel.sup!
          expect(round.sups.count).to eq 1
          expect(round.sups.first.users.count).to eq 4
          expect(channel).to have_received(:inform!).with(
            "Hi! I have created a new round with 1 S'Up, pairing all of 4 users."
          )
        end

        context 'with sup_odd set to false' do
          before do
            channel.update_attributes!(sup_odd: false)
          end

          it 'does not add a user to the existing round' do
            round = channel.sup!
            expect(round.sups.count).to eq 1
            expect(round.sups.first.users.count).to eq 3
            expect(channel).to have_received(:inform!).with(
              "Hi! I have created a new round with 1 S'Up, pairing 3 users. Unfortunately, I wasn't able to find a group for the remaining 1. Consider increasing the value of `@sup set weeks`, lowering the value of `@sup set recency`, or adjusting `@sup set odd`."
            )
          end
        end
      end

      context 'with a number of users not divisible by sup_size' do
        let!(:user4) { Fabricate(:user, channel:) }
        let!(:user5) { Fabricate(:user, channel:) }

        it 'generates a sup for the remaining users' do
          expect do
            channel.sup!
          end.to change(Sup, :count).by(2)
          expect(channel).to have_received(:inform!).with(
            "Hi! I have created a new round with 2 S'Ups, pairing all of 5 users."
          )
        end

        context 'with sup_odd set to false' do
          before do
            channel.update_attributes!(sup_odd: false)
          end

          it 'does not generate a sup for the remaining users' do
            expect do
              channel.sup!
            end.to change(Sup, :count).by(1)
            expect(channel).to have_received(:inform!).with(
              "Hi! I have created a new round with 1 S'Up, pairing 3 users. Unfortunately, I wasn't able to find a group for the remaining 2. Consider increasing the value of `@sup set weeks`, lowering the value of `@sup set recency`, or adjusting `@sup set odd`."
            )
          end
        end
      end

      context 'with a recent sup and new users' do
        let!(:first_round) { channel.sup! }

        before do
          Fabricate(:user, channel:)
          Fabricate(:user, channel:)
        end

        it 'generates a sup with new users and one old one' do
          expect(first_round.total_users_count).to eq 3
          expect(first_round.opted_in_users_count).to eq 3
          expect(first_round.opted_out_users_count).to eq 0
          expect(first_round.paired_users_count).to eq 3
          expect(first_round.missed_users_count).to eq 0
          second_round = channel.sup!
          expect(second_round.total_users_count).to eq 5
          expect(second_round.opted_in_users_count).to eq 5
          expect(second_round.opted_out_users_count).to eq 0
          expect(second_round.paired_users_count).to eq 3
          expect(second_round.missed_users_count).to eq 2
          expect(channel).to have_received(:inform!).with(
            "Hi! I have created a new round with 1 S'Up, pairing 3 users. Unfortunately, I wasn't able to find a group for the remaining 2. Consider increasing the value of `@sup set weeks`, lowering the value of `@sup set recency`, or adjusting `@sup set odd`."
          )
        end
      end

      context 'opted out' do
        let!(:user4) { Fabricate(:user, channel:) }

        before do
          user3.update_attributes!(opted_in: false)
        end

        it 'excludes opted out users' do
          expect do
            channel.sup!
          end.to change(Sup, :count).by(1)
          sup = Sup.first
          expect(sup.users).to eq([user1, user2, user4])
          expect(channel).to have_received(:inform!).with(
            "Hi! I have created a new round with 1 S'Up, pairing all of 3 users."
          )
        end

        it 'updates counts' do
          expect do
            channel.sup!
          end.to change(Round, :count).by(1)
          round = Round.first
          expect(round.total_users_count).to eq 4
          expect(round.opted_in_users_count).to eq 3
          expect(round.opted_out_users_count).to eq 1
          expect(round.paired_users_count).to eq 3
          expect(round.missed_users_count).to eq 0
        end
      end

      context 'disabled' do
        let!(:user4) { Fabricate(:user, channel:) }

        before do
          user3.update_attributes!(enabled: false)
        end

        it 'excludes opted out users' do
          expect do
            channel.sup!
          end.to change(Sup, :count).by(1)
          sup = Sup.first
          expect(sup.users).to eq([user1, user2, user4])
          expect(channel).to have_received(:inform!).with(
            "Hi! I have created a new round with 1 S'Up, pairing all of 3 users."
          )
        end

        it 'updates counts' do
          expect do
            channel.sup!
          end.to change(Round, :count).by(1)
          round = Round.first
          expect(round.total_users_count).to eq 3
          expect(round.opted_in_users_count).to eq 3
          expect(round.opted_out_users_count).to eq 0
          expect(round.paired_users_count).to eq 3
          expect(round.missed_users_count).to eq 0
        end
      end
    end
  end

  context 'a sup round' do
    let!(:user1) { Fabricate(:user, channel:) }
    let!(:user2) { Fabricate(:user, channel:) }
    let!(:user3) { Fabricate(:user, channel:) }
    let!(:round) { channel.sup! }

    describe '#met_recently?' do
      let!(:round2) { channel.sup! }

      it 'is true when users just met' do
        expect(round2.send(:met_recently?, [user1, user2])).to be true
      end

      context 'in not so distant future' do
        before do
          Timecop.travel(Time.now.utc + 1.week)
        end

        it 'is true' do
          expect(round2.send(:met_recently?, [user1, user2])).to be true
        end
      end

      context 'in a distant future' do
        before do
          Timecop.travel(Time.now.utc + channel.sup_recency.weeks)
        end

        it 'is false in some distant future' do
          expect(round2.send(:met_recently?, [user1, user2])).to be false
        end

        it 'is true with a sup with both users' do
          Fabricate(:sup, round:, channel:, users: [user1, user2, Fabricate(:user, channel:)])
          expect(round2.send(:met_recently?, [user1, user2])).to be true
        end

        it 'is false with a sup with one user' do
          Fabricate(:sup, round:, channel:, users: [Fabricate(:user), user2, Fabricate(:user)])
          expect(round2.send(:met_recently?, [user1, user2])).to be false
        end
      end
    end

    describe '#same_team?' do
      it 'is false without custom teams' do
        expect(round.send(:same_team?, [user1, user2, user3])).to be false
      end

      it 'is false when one team set' do
        user1.custom_team_name = 'My Team'
        expect(round.send(:same_team?, [user1, user2, user3])).to be false
      end

      it 'is false when different names' do
        user1.custom_team_name = 'My Team'
        user2.custom_team_name = 'Another Team'
        expect(round.send(:same_team?, [user1, user2])).to be false
        expect(round.send(:same_team?, [user1, user2, user3])).to be false
      end

      it 'is true when same team' do
        user1.custom_team_name = 'My Team'
        user2.custom_team_name = 'My Team'
        expect(round.send(:same_team?, [user1, user2])).to be true
      end

      it 'is true when same team for any two users' do
        user1.custom_team_name = 'My Team'
        user3.custom_team_name = 'My Team'
        expect(round.send(:same_team?, [user1, user2, user3])).to be true
      end

      it 'is true when same team for all 3 users' do
        user1.custom_team_name = 'My Team'
        user2.custom_team_name = 'My Team'
        user3.custom_team_name = 'My Team'
        expect(round.send(:same_team?, [user1, user2, user3])).to be true
      end
    end

    describe '#ask?' do
      it 'is false within 24 hours even if sup_followup_wday is today' do
        channel.update_attributes!(sup_followup_wday: DateTime.now.wday)
        expect(round.ask?).to be false
      end

      it 'is false immediately after the round' do
        expect(round.ask?).to be false
      end

      context 'have not asked already' do
        before do
          channel.update_attributes!(sup_wday: Date::TUESDAY, sup_followup_wday: Date::FRIDAY)
        end

        let(:wednesday_est_before_time_of_day) { DateTime.parse('2042/1/8 8:00 AM EST').utc }
        let(:wednesday_est_after_time_of_day) { DateTime.parse('2042/1/8 3:00 PM EST').utc }
        let(:thursday_morning_utc) { DateTime.parse('2042/1/9 0:00 AM UTC').utc }
        let(:thursday_est) { DateTime.parse('2042/1/9 3:00 PM EST').utc }
        let(:friday_est) { DateTime.parse('2042/1/10 3:00 PM EST').utc }

        it 'is false for Wednesday eastern time' do
          Timecop.travel(wednesday_est_after_time_of_day) do
            expect(round.ask?).to be false
          end
        end

        it 'is false for Thursday morning utc time when channel is eastern time' do
          Timecop.travel(thursday_morning_utc) do
            expect(round.ask?).to be false
          end
        end

        it 'is false for Thursday eastern because sup on a Tuesday, remind on Friday' do
          Timecop.travel(thursday_est) do
            expect(round.ask?).to be false
          end
        end

        it 'is true for Friday eastern because sup on a Tuesday, remind on Friday' do
          Timecop.travel(friday_est) do
            expect(round.ask?).to be true
          end
        end

        context 'channel.followup_day Wednesday' do
          before do
            channel.update_attributes!(sup_followup_wday: Date::WEDNESDAY)
          end

          it 'is true after sup time of day' do
            Timecop.travel(wednesday_est_after_time_of_day) do
              expect(round.ask?).to be true
            end
          end

          it 'is false before sup time of day' do
            Timecop.travel(wednesday_est_before_time_of_day) do
              expect(round.ask?).to be false
            end
          end
        end
      end

      context 'on Thursday days and already asked' do
        before do
          round.update_attributes!(asked_at: Time.now.utc)
          Timecop.travel(Time.now - Time.now.wday.days + 4.days)
        end

        it 'is false' do
          expect(round.ask?).to be false
        end
      end
    end

    describe '#ask!' do
      context 'with a sup' do
        let!(:sup) { Fabricate(:sup, channel:, round:) }

        it 'asks every sup' do
          expect(sup).to receive(:ask!).once
          round.ask!
        end

        it 'updates asked_at' do
          expect(round.asked_at).to be_nil
          round.ask!
          expect(round.asked_at).not_to be_nil
        end
      end
    end

    describe '#remind?' do
      let(:wednesday_est_before_time_of_day) { DateTime.parse('2042/1/8 8:00 AM EST').utc }
      let(:wednesday_est_after_time_of_day) { DateTime.parse('2042/1/8 3:00 PM EST').utc }

      it 'is false immediately after the round' do
        expect(round.remind?).to be false
      end

      context 'have not reminded already' do
        it 'is false 12 hours later' do
          Timecop.travel(round.created_at + 12.hours) do
            expect(round.remind?).to be false
          end
        end

        it 'is true after sup time of day' do
          Timecop.travel(wednesday_est_after_time_of_day) do
            expect(round.remind?).to be true
          end
        end

        it 'is false before sup time of day' do
          Timecop.travel(wednesday_est_before_time_of_day) do
            expect(round.remind?).to be false
          end
        end
      end

      context 'already reminded' do
        before do
          round.update_attributes!(reminded_at: Time.now.utc)
        end

        it 'is false' do
          Timecop.travel(round.created_at + 25.hours) do
            expect(round.remind?).to be false
          end
        end
      end
    end

    describe '#remind!' do
      context 'with a sup' do
        let!(:sup) { Fabricate(:sup, channel:, round:) }

        it 'reminds every sup' do
          expect(sup).to receive(:remind!).once
          round.remind!
        end

        it 'updates reminded_at' do
          expect(round.reminded_at).to be_nil
          round.remind!
          expect(round.reminded_at).not_to be_nil
        end
      end
    end

    describe '#ask_again?' do
      it 'is false within 36 hours even if asked_at' do
        round.update_attributes!(asked_at: Time.now - 36.hours)
        expect(round.ask_again?).to be false
      end

      it 'is true after 48 hours if asked_at' do
        round.update_attributes!(asked_at: Time.now - 72.hours)
        expect(round.ask_again?).to be true
      end

      it 'is false immediately after the round' do
        expect(round.ask_again?).to be false
      end
    end

    describe '#ask_again!' do
      before do
        round.update_attributes!(asked_at: Time.now - 72.hours)
      end

      it 'updates asked_again_at' do
        expect(round.asked_again_at).to be_nil
        round.ask_again!
        expect(round.asked_again_at).not_to be_nil
      end

      context 'with a sup having a later outcome' do
        let!(:sup) { Fabricate(:sup, channel:, round:, outcome: 'later') }

        it 'ask_again every sup' do
          expect(round.sups).to receive(:where).with(outcome: 'later').and_return([sup])
          expect(sup).to receive(:ask_again!).once
          round.ask_again!
        end
      end

      context 'with a sup having a different outcome' do
        it 'does not ask_again' do
          expect(round.sups.count).to be >= 0
          round.sups.each do |sup|
            expect(sup).not_to receive(:ask_again!)
          end
          round.ask_again!
        end
      end
    end

    describe '#export' do
      include_context 'uses temp dir'

      before do
        round.export!(tmp)
      end

      %w[round sups].each do |csv|
        it "creates #{csv}.csv" do
          expect(File.exist?(File.join(tmp, "#{csv}.csv"))).to be true
        end
      end

      context 'round.csv' do
        let(:csv) { CSV.read(File.join(tmp, 'round.csv'), headers: true) }

        it 'generates csv' do
          expect(csv.headers).to eq(
            %w[
              id
              total_users_count
              opted_in_users_count
              opted_out_users_count
              paired_users_count
              missed_users_count
              ran_at
              asked_at
              created_at
              updated_at
              paired_users
              missed_users
            ]
          )
          row = csv[0]
          expect(row['total_users_count']).to eq '3'
          expect(row['missed_users']).to eq round.missed_users.map(&:user_name).join("\n")
          expect(row['paired_users']).to eq round.paired_users.map(&:user_name).join("\n")
        end
      end
    end
  end

  describe '#dm!' do
    pending 'opens a DM channel with users'
    pending 'sends users a sup message'
  end
end
