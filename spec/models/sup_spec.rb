require 'spec_helper'

describe Sup do
  context 'a sup' do
    let(:sup) { Fabricate(:sup) }

    before do
      allow_any_instance_of(Channel).to receive(:inform!)
    end

    it 'asks for outcome' do
      message = Sup::ASK_WHO_SUP_MESSAGE.dup
      message[:attachments][0][:callback_id] = sup.id.to_s
      expect(sup).to receive(:dm!).with(message)
      sup.ask!
    end

    it 'asks again for outcome' do
      message = Sup::ASK_WHO_SUP_AGAIN_MESSAGE.dup
      message[:attachments][0][:callback_id] = sup.id.to_s
      expect(sup).to receive(:dm!).with(message)
      sup.ask_again!
    end

    describe '#remind' do
      context 'having not messaged' do
        it 'no reminder' do
          expect(sup).not_to receive(:dm!)
          sup.remind!
        end
      end

      context 'with channel' do
        before do
          sup.update_attributes!(conversation_id: 'channel')
        end

        it 'reminds for outcome' do
          expect(sup.send(:slack_client)).to receive(:conversations_history).and_return(Hashie::Mash.new(messages: []))
          expect(sup).to receive(:dm!).with(text: 'Bumping myself on top of your list.')
          sup.remind!
        end

        context 'with captain' do
          let(:captain) { Fabricate(:user, channel: sup.channel) }

          before do
            sup.update_attributes!(captain:)
          end

          it 'pings captain' do
            expect(sup.send(:slack_client)).to receive(:conversations_history).and_return(Hashie::Mash.new(messages: []))
            expect(sup).to receive(:dm!).with(text: "Bumping myself on top of your list, #{captain.slack_mention}.")
            sup.remind!
          end
        end

        it 'does not remind if a conversation has been had' do
          expect(sup.send(:slack_client)).to receive(:conversations_history).and_return(Hashie::Mash.new(messages: [1, 2]))
          expect(sup).not_to receive(:dm!)
          sup.remind!
        end
      end
    end

    describe '#calendar_href' do
      it 'includes date/time and sup id and a valid access token' do
        t = Time.now.utc
        href = URI.parse(sup.calendar_href(t))
        expect(href).to be_a URI::HTTPS
        params = Rack::Utils.parse_nested_query(href.query)
        expect(params['sup_id']).to eq sup.id.to_s
        expect(sup.channel.short_lived_token_valid?(params['access_token'])).to be true
        expect(params['dt'].to_i).to eq t.to_i
      end
    end
  end

  context 'a channel' do
    let(:channel) { Fabricate(:channel, sup_wday: Date::MONDAY, sup_followup_wday: Date::THURSDAY) }
    let!(:user1) { Fabricate(:user, channel:) }
    let!(:user2) { Fabricate(:user, channel:) }
    let!(:user3) { Fabricate(:user, channel:) }

    before do
      allow(channel).to receive(:sync!)
      allow(channel).to receive(:inform!)
      allow_any_instance_of(Sup).to receive(:dm!)
      channel.sup!
    end

    context 'a round' do
      let!(:round) { channel.rounds.first }

      it 'generates sups' do
        expect(round.sups.count).to eq 1
      end

      context 'sup' do
        let(:sup) { round.sups.first }

        context 'intro message' do
          it 'everyone is new' do
            sup.users.each { |u| u.update_attributes!(introduced_sup_at: nil) }
            expect(sup.send(:intro_message)).to eq(
              "The most valuable relationships are not made of 2 people, they're made of 3. " \
              "Channel S'Up connects groups of 3 people from <##{sup.channel.channel_id}> on Monday every week. " \
              "Welcome #{sup.users.asc(:_id).map(&:slack_mention).and}, excited for your first S'Up!"
            )
          end

          it 'two are new' do
            users = sup.users.take(2).sort_by(&:id)
            users.each { |u| u.update_attributes!(introduced_sup_at: nil) }
            expect(sup.send(:intro_message)).to eq(
              "The most valuable relationships are not made of 2 people, they're made of 3. " \
              "Channel S'Up connects groups of 3 people from <##{sup.channel.channel_id}> on Monday every week. " \
              "Welcome #{users.map(&:slack_mention).and}, excited for your first S'Up!"
            )
          end

          it 'one is new' do
            sup.users.first.update_attributes!(introduced_sup_at: nil)
            expect(sup.send(:intro_message)).to eq(
              "The most valuable relationships are not made of 2 people, they're made of 3. " \
              "Channel S'Up connects groups of 3 people from <##{sup.channel.channel_id}> on Monday every week. " \
              "Welcome #{sup.users.first.slack_mention}, excited for your first S'Up!"
            )
          end

          it 'one is new and sup_size is not 3' do
            sup.channel.update_attributes!(sup_size: 2)
            sup.users.first.update_attributes!(introduced_sup_at: nil)
            expect(sup.send(:intro_message)).to eq(
              "Channel S'Up connects groups of 2 people from <##{sup.channel.channel_id}> on Monday every week. " \
              "Welcome #{sup.users.first.slack_mention}, excited for your first S'Up!"
            )
          end

          it 'nobody is new' do
            expect(sup.send(:intro_message)).to be_nil
          end
        end

        describe '#export' do
          include_context 'uses temp dir'

          before do
            sup.export!(tmp)
          end

          %w[sup].each do |csv|
            it "creates #{csv}.csv" do
              expect(File.exist?(File.join(tmp, "#{csv}.csv"))).to be true
            end
          end

          context 'sup.csv' do
            let(:csv) { CSV.read(File.join(tmp, 'sup.csv'), headers: true) }

            it 'generates csv' do
              expect(csv.headers).to eq(%w[id outcome created_at updated_at captain_user_name users])
              row = csv[0]
              expect(row['outcome']).to be_nil
              expect(row['users']).to eq sup.users.map(&:user_name).join("\n")
              expect(row['captain_user_name']).to eq sup.captain.user_name
            end
          end
        end
      end
    end
  end

  context 'sup!' do
    let(:channel) { Fabricate(:channel, sup_wday: Date::MONDAY, sup_followup_wday: Date::THURSDAY) }
    let!(:user1) { Fabricate(:user, channel:) }
    let!(:user2) { Fabricate(:user, channel:) }
    let!(:user3) { Fabricate(:user, channel:) }

    before do
      allow(channel).to receive(:sync!)
      allow(channel).to receive(:inform!)
    end

    it 'uses default message' do
      expect_any_instance_of(Sup).to receive(:dm!).with(
        text: /Please find a time for a quick 20 minute break on the calendar./
      )
      channel.sup!
    end

    it 'includes intro message' do
      expect_any_instance_of(Sup).to receive(:dm!).with(
        text: /Channel S'Up connects groups of 3 people from <##{channel.channel_id}> on Monday every week. Welcome #{channel.users.asc(:_id).map(&:slack_mention).and}, excited for your first S'Up!/
      )
      channel.sup!
    end

    it 'uses a custom message' do
      channel.update_attributes!(sup_message: 'SUP SUP')
      allow(channel).to receive(:sync!)
      allow(channel).to receive(:inform!)
      expect_any_instance_of(Sup).to receive(:dm!).with(
        text: /SUP SUP/
      )
      channel.sup!
    end

    it 'mentions SUP captain' do
      expect_any_instance_of(Sup).to receive(:dm!).with(
        text: /(#{user1.slack_mention}|#{user2.slack_mention}|#{user3.slack_mention}), you're in charge this week to make it happen!/
      )
      expect do
        channel.sup!
      end.to change(Sup, :count).by(1)
      sup = channel.sups.first
      expect(channel.users).to include sup.captain
    end

    context 'chooses captain' do
      before do
        allow_any_instance_of(Sup).to receive(:dm!)
        allow_any_instance_of(Round).to receive(:run!)
      end

      it 'picks the user who has never been captain' do
        Fabricate(:sup, captain: user1, created_at: 4.weeks.ago)
        Fabricate(:sup, captain: user1, created_at: 5.weeks.ago)
        Fabricate(:sup, captain: user2, created_at: 6.weeks.ago)
        user4 = Fabricate(:user, channel:)
        sup = Fabricate(:sup, user_ids: [user1.id, user2.id, user4.id])
        sup.sup!
        expect(sup.captain).to eq user4
      end

      it 'picks the user who has not been captain for the longest' do
        Fabricate(:sup, captain: user1, created_at: 4.weeks.ago)
        Fabricate(:sup, captain: user1, created_at: 5.weeks.ago)
        Fabricate(:sup, captain: user2, created_at: 6.weeks.ago)
        Fabricate(:sup, captain: user3, created_at: 3.weeks.ago)
        sup = Fabricate(:sup, user_ids: [user1.id, user2.id, user3.id])
        sup.sup!
        expect(sup.captain).to eq user2
      end
    end
  end
end
