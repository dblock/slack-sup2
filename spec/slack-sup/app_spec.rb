require 'spec_helper'

describe SlackSup::App do
  subject do
    SlackSup::App.instance
  end

  describe '#instance' do
    it 'is an instance of the app' do
      expect(subject).to be_a(SlackRubyBotServer::App)
      expect(subject).to be_an_instance_of(SlackSup::App)
    end
  end

  describe '#purge_inactive_teams!' do
    it 'purges teams' do
      expect(Team).to receive(:purge!)
      subject.send(:purge_inactive_teams!)
    end
  end

  describe '#deactivate_asleep_teams!' do
    let!(:active_team) { Fabricate(:team, created_at: Time.now.utc) }
    let!(:active_team_one_week_ago) { Fabricate(:team, created_at: 1.week.ago) }
    let!(:active_team_three_weeks_ago) { Fabricate(:team, created_at: 3.weeks.ago) }
    let!(:subscribed_team_a_month_ago) { Fabricate(:team, created_at: 1.month.ago, subscribed: true) }

    it 'destroys teams inactive for two weeks' do
      expect_any_instance_of(Team).to receive(:inform!).with(
        "The S'Up bot hasn't been used for 3 weeks, deactivating. Reactivate at #{SlackRubyBotServer::Service.url}. Your data will be purged in another 2 weeks."
      ).once
      subject.send(:deactivate_asleep_teams!)
      expect(active_team.reload.active).to be true
      expect(active_team_one_week_ago.reload.active).to be true
      expect(active_team_three_weeks_ago.reload.active).to be false
      expect(subscribed_team_a_month_ago.reload.active).to be true
    end
  end

  describe '#sync!' do
    let!(:team) { Fabricate(:team) }
    let!(:team_user) { User.create!(team:, user_id: 'U123', sync: true) }
    let!(:team2) { Fabricate(:team) }
    let!(:channel) { Fabricate(:channel, team:, sync: true) }

    it 'syncs all active teams and pending channels' do
      expect(Team).to receive(:active).and_return([team, team2])
      expect(team).to receive(:sync!) do |instance|
        instance.users.where(channel_id: nil).update_all(updated_at: Time.now.utc, sync: false)
      end
      expect(team2).to receive(:sync!) do |instance|
        instance.users.where(channel_id: nil).update_all(updated_at: Time.now.utc, sync: false)
      end
      expect_any_instance_of(Channel).to receive(:sync!).once

      subject.send(:sync!)
    end
  end

  context 'subscribed' do
    include_context 'stripe mock'
    let(:plan) { stripe_helper.create_plan(id: 'slack-sup2-yearly', amount: 3999) }
    let(:customer) { Stripe::Customer.create(source: stripe_helper.generate_card_token, plan: plan.id, email: 'foo@bar.com', metadata: { team_id: 'T_EXTERNAL', name: 'External Team' }) }
    let!(:team) { Fabricate(:team, subscribed: true, stripe_customer_id: customer.id) }

    describe '#check_subscribed_teams!' do
      it 'ignores active subscriptions' do
        expect_any_instance_of(Team).not_to receive(:inform!)
        subject.send(:check_subscribed_teams!)
      end

      it 'notifies past due subscription' do
        customer.subscriptions.data.first['status'] = 'past_due'
        expect(Stripe::Customer).to receive(:retrieve).and_return(customer)
        allow_any_instance_of(Team).to receive(:short_lived_token).and_return('token')
        expect_any_instance_of(Team).to receive(:inform!).with("Your subscription to StripeMock Default Plan ID ($39.99) is past due. #{team.update_cc_text}")
        subject.send(:check_subscribed_teams!)
        expect(team.reload.past_due_informed_at).not_to be_nil
      end

      it 'does not re-notify past due subscription within 72 hours' do
        team.update_attributes!(past_due_informed_at: 1.hour.ago)
        customer.subscriptions.data.first['status'] = 'past_due'
        expect(Stripe::Customer).to receive(:retrieve).and_return(customer)
        expect_any_instance_of(Team).not_to receive(:inform!)
        subject.send(:check_subscribed_teams!)
      end

      it 'notifies past due subscription again after 72 hours' do
        team.update_attributes!(past_due_informed_at: 73.hours.ago)
        customer.subscriptions.data.first['status'] = 'past_due'
        expect(Stripe::Customer).to receive(:retrieve).and_return(customer)
        allow_any_instance_of(Team).to receive(:short_lived_token).and_return('token')
        expect_any_instance_of(Team).to receive(:inform!).with("Your subscription to StripeMock Default Plan ID ($39.99) is past due. #{team.update_cc_text}")
        subject.send(:check_subscribed_teams!)
      end

      it 'notifies canceled subscription' do
        customer.subscriptions.data.first['status'] = 'canceled'
        team.update_attributes!(past_due_informed_at: 1.hour.ago)
        expect(Stripe::Customer).to receive(:retrieve).and_return(customer)
        expect_any_instance_of(Team).to receive(:inform!).with('Your subscription to StripeMock Default Plan ID ($39.99) was canceled and your team has been downgraded. Thank you for being a customer!')
        subject.send(:check_subscribed_teams!)
        expect(team.reload.subscribed?).to be false
        expect(team.reload.past_due_informed_at).to be_nil
      end

      it 'notifies no active subscriptions' do
        customer.subscriptions.data = []
        expect(Stripe::Customer).to receive(:retrieve).and_return(customer)
        expect_any_instance_of(Team).to receive(:inform!).with('Your subscription was canceled and your team has been downgraded. Thank you for being a customer!')
        subject.send(:check_subscribed_teams!)
        expect(team.reload.subscribed?).to be false
      end
    end

    describe '#check_stripe_subscribers!' do
      let(:subscription) { customer.subscriptions.data.first }
      let(:subscription_list) { instance_double(Stripe::ListObject) }

      before do
        allow(Stripe::Subscription).to receive(:list).with(plan: 'slack-sup2-yearly').and_return(subscription_list)
      end

      context 'team found by stripe_customer_id, already subscribed and active' do
        before do
          allow(Stripe::Customer).to receive(:retrieve).and_return(customer)
          allow(subscription_list).to receive(:auto_paging_each).and_yield(subscription)
        end

        it 'skips the team' do
          expect_any_instance_of(Team).not_to receive(:update_attributes!)
          subject.send(:check_stripe_subscribers!)
          expect(team.reload.subscribed?).to be true
        end
      end

      context 'team found by stripe_customer_id, active but not subscribed' do
        let!(:team) { Fabricate(:team, subscribed: false, stripe_customer_id: customer.id) }

        before do
          allow(Stripe::Customer).to receive(:retrieve).and_return(customer)
          allow(subscription_list).to receive(:auto_paging_each).and_yield(subscription)
        end

        it 're-associates and marks subscribed' do
          allow_any_instance_of(Team).to receive(:inform!)
          expect(subject.logger).to receive(:warn).with(/Re-associating customer_id/)
          subject.send(:check_stripe_subscribers!)
          expect(team.reload.subscribed?).to be true
        end
      end

      context 'team found by metadata team_id, active but not subscribed' do
        let(:customer_with_metadata) do
          Stripe::Customer.create(
            source: stripe_helper.generate_card_token,
            plan: plan.id,
            email: 'bar@baz.com',
            metadata: { team_id: team.team_id, name: 'Test Team' }
          )
        end
        let(:subscription_with_metadata) { customer_with_metadata.subscriptions.data.first }
        let!(:team) { Fabricate(:team, subscribed: false, stripe_customer_id: nil) }

        before do
          allow(Stripe::Customer).to receive(:retrieve).with(customer_with_metadata.id).and_return(customer_with_metadata)
          allow(subscription_list).to receive(:auto_paging_each).and_yield(subscription_with_metadata)
        end

        it 're-associates and marks subscribed' do
          allow_any_instance_of(Team).to receive(:inform!)
          expect(subject.logger).to receive(:warn).with(/Re-associating customer_id/)
          subject.send(:check_stripe_subscribers!)
          expect(team.reload.subscribed?).to be true
          expect(team.reload.stripe_customer_id).to eq(customer_with_metadata.id)
        end
      end

      context 'team is inactive with an active stripe subscription' do
        let!(:team) { Fabricate(:team, subscribed: true, active: false, stripe_customer_id: customer.id) }

        before do
          allow(Stripe::Customer).to receive(:retrieve).and_return(customer)
          allow(subscription_list).to receive(:auto_paging_each).and_yield(subscription)
        end

        it 'cancels auto-renew' do
          expect(Stripe::Subscription).to receive(:update).with(subscription.id, cancel_at_period_end: true)
          expect(subject.logger).to receive(:warn).with(/Inactive team/)
          expect(subject.logger).to receive(:warn).with(/Successfully canceled auto-renew/)
          subject.send(:check_stripe_subscribers!)
        end
      end

      context 'team is inactive with no active stripe subscription' do
        let!(:team) { Fabricate(:team, subscribed: false, active: false, stripe_customer_id: customer.id) }

        before do
          allow(Stripe::Customer).to receive(:retrieve).and_return(customer)
          allow(subscription_list).to receive(:auto_paging_each).and_yield(subscription)
          allow_any_instance_of(Team).to receive(:active_stripe_subscription).and_return(nil)
        end

        it 'logs inactive team with no subscription' do
          expect(subject.logger).to receive(:warn).with(/no active subscription to cancel/)
          subject.send(:check_stripe_subscribers!)
        end
      end

      context 'team not found' do
        let(:unknown_customer) do
          Stripe::Customer.create(
            source: stripe_helper.generate_card_token,
            plan: plan.id,
            email: 'unknown@baz.com',
            metadata: { team_id: 'TNOTFOUND', name: 'Unknown Team' }
          )
        end
        let(:unknown_subscription) { unknown_customer.subscriptions.data.first }

        before do
          allow(Stripe::Customer).to receive(:retrieve).with(unknown_customer.id).and_return(unknown_customer)
          allow(subscription_list).to receive(:auto_paging_each).and_yield(unknown_subscription)
        end

        it 'logs contact info' do
          expect(subject.logger).to receive(:warn).with(/Cannot find team for Unknown Team \(TNOTFOUND\), contact unknown@baz.com/)
          subject.send(:check_stripe_subscribers!)
        end
      end

      context 'error handling' do
        before do
          allow(Stripe::Customer).to receive(:retrieve).and_raise(StandardError, 'stripe error')
          allow(subscription_list).to receive(:auto_paging_each).and_yield(subscription)
        end

        it 'logs error and continues' do
          expect(subject.logger).to receive(:warn).with(/Error checking customer .*, stripe error/)
          subject.send(:check_stripe_subscribers!)
        end
      end
    end
  end

  context 'sup!' do
    let(:wday) { Time.now.utc.in_time_zone('Eastern Time (US & Canada)').wday }
    let(:active_team) { Fabricate(:team) }
    let!(:active_team_channel) { Fabricate(:channel, team: active_team, sup_wday: wday, sup_time_of_day: 1) }
    let(:inactive_team) { Fabricate(:team, active: false) }
    let!(:inactive_team_channel) { Fabricate(:channel, sup_wday: wday, sup_time_of_day: 1, team: inactive_team) }

    it 'sups only active teams' do
      expect(inactive_team_channel.sup?).to be false
      expect(active_team_channel.sup?).to be true
      expect_any_instance_of(Channel).to receive(:sup!).once.and_call_original
      expect_any_instance_of(Channel).to receive(:sync!)
      expect_any_instance_of(Channel).to receive(:inform!)
      subject.send(:sup!)
    end
  end

  context 'leave!' do
    let(:team) { Fabricate(:team) }
    let!(:channel1) { Fabricate(:channel, team:) }
    let!(:channel2) { Fabricate(:channel, team:) }

    it 'removes bot from channel' do
      expect(Channel).to receive(:enabled).and_return([channel1, channel2])

      allow_any_instance_of(Channel).to receive(:bot_in_channel?) do |channel|
        case channel.channel_id
        when channel1.channel_id
          false
        when channel2.channel_id
          true
        end
      end

      expect(channel1).to receive(:leave!).and_call_original
      expect(channel2).not_to receive(:leave!)

      subject.send(:leave!)

      expect(channel1.reload.enabled).to be false
      expect(channel2.reload.enabled).to be true
    end
  end

  context 'check_channel_auth!' do
    let(:team) { Fabricate(:team) }
    let!(:channel1) { Fabricate(:channel, team:) }
    let!(:channel2) { Fabricate(:channel, team:) }
    let!(:channel3) { Fabricate(:channel, team:) }
    let!(:channel4) { Fabricate(:channel, team:) }

    it 'disables on account_inactive' do
      allow_any_instance_of(Slack::Web::Client).to receive(:conversations_info) do |_, channel|
        case channel[:channel]
        when channel1.channel_id
          raise Slack::Web::Api::Errors::SlackError, 'account_inactive'
        when channel2.channel_id
          raise Slack::Web::Api::Errors::SlackError, 'some_other_error'
        when channel3.channel_id
          raise StandardError, 'some_other_error'
        end
      end
      subject.send(:check_channel_auth!)
      expect(channel1.reload.enabled).to be false
      expect(channel2.reload.enabled).to be true
      expect(channel3.reload.enabled).to be true
      expect(channel4.reload.enabled).to be true
    end
  end

  context 'check_expired_subscriptions!' do
    context 'expired trial' do
      let!(:team) { Fabricate(:team, created_at: 3.weeks.ago) }

      it 'informs team with an expired subscription' do
        expect_any_instance_of(Team).to receive(:inform!)
        expect_any_instance_of(Logger).to receive(:info).with(/subscription has expired/)
        subject.send(:check_expired_subscriptions!)
      end
    end

    context 'non expired trial' do
      let!(:team) { Fabricate(:team, created_at: 1.week.ago) }

      it 'logs trial' do
        expect_any_instance_of(Logger).to receive(:info).with(/trial ends in \d days/)
        subject.send(:check_expired_subscriptions!)
      end
    end

    context 'subscribed team' do
      let!(:team) { Fabricate(:team, subscribed: true) }

      it 'no logs' do
        expect_any_instance_of(Logger).not_to receive(:info)
        subject.send(:check_expired_subscriptions!)
      end
    end
  end

  context 'close_old_sups!' do
    let!(:team) { Fabricate(:team) }
    let!(:channel) { Fabricate(:channel, team:, sup_close: true) }

    context 'with only one round' do
      let!(:round) { Fabricate(:round, channel:, ran_at: 1.week.ago) }
      let!(:sup) { Fabricate(:sup, channel:, round:, conversation_id: 'C_ONLY') }

      it 'does not close the only round' do
        expect_any_instance_of(Slack::Web::Client).not_to receive(:conversations_close)
        subject.send(:close_old_sups!)
        expect(sup.reload.closed_at).to be_nil
      end
    end

    context 'with multiple rounds' do
      let!(:old_round) { Fabricate(:round, channel:, ran_at: 2.weeks.ago) }
      let!(:new_round) { Fabricate(:round, channel:, ran_at: 1.week.ago) }
      let!(:old_sup) { Fabricate(:sup, channel:, round: old_round, conversation_id: 'C_OLD') }
      let!(:new_sup) { Fabricate(:sup, channel:, round: new_round, conversation_id: 'C_NEW') }
      let!(:already_closed_sup) { Fabricate(:sup, channel:, round: old_round, conversation_id: 'C_CLOSED', closed_at: 1.day.ago) }
      let!(:no_conversation_sup) { Fabricate(:sup, channel:, round: old_round) }

      it 'closes only open DMs from rounds superseded by a newer round' do
        expect_any_instance_of(Slack::Web::Client).to receive(:conversations_close).once.with(channel: 'C_OLD')
        subject.send(:close_old_sups!)
        expect(old_sup.reload.closed_at).not_to be_nil
        expect(new_sup.reload.closed_at).to be_nil
        expect(already_closed_sup.reload.closed_at).not_to be_nil
        expect(no_conversation_sup.reload.closed_at).to be_nil
      end
    end

    context 'with more closeable DMs than the per-run limit' do
      let!(:channel1) { Fabricate(:channel, team:, sup_close: true) }
      let!(:channel2) { Fabricate(:channel, team:, sup_close: true) }

      let!(:channel1_old_round) { Fabricate(:round, channel: channel1, ran_at: 2.weeks.ago) }
      let!(:channel1_new_round) { Fabricate(:round, channel: channel1, ran_at: 1.week.ago) }
      let!(:channel2_old_round) { Fabricate(:round, channel: channel2, ran_at: 2.weeks.ago) }
      let!(:channel2_new_round) { Fabricate(:round, channel: channel2, ran_at: 1.week.ago) }

      let!(:channel1_old_sup1) { Fabricate(:sup, channel: channel1, round: channel1_old_round, conversation_id: 'C_OLD_1') }
      let!(:channel1_old_sup2) { Fabricate(:sup, channel: channel1, round: channel1_old_round, conversation_id: 'C_OLD_2') }
      let!(:channel2_old_sup1) { Fabricate(:sup, channel: channel2, round: channel2_old_round, conversation_id: 'C_OLD_3') }
      let!(:channel2_old_sup2) { Fabricate(:sup, channel: channel2, round: channel2_old_round, conversation_id: 'C_OLD_4') }
      let!(:channel1_new_sup) { Fabricate(:sup, channel: channel1, round: channel1_new_round, conversation_id: 'C_NEW_1') }
      let!(:channel2_new_sup) { Fabricate(:sup, channel: channel2, round: channel2_new_round, conversation_id: 'C_NEW_2') }

      before do
        stub_const('SlackSup::App::MAX_OLD_SUPS_TO_CLOSE_PER_RUN', 2)
        allow(Channel).to receive(:enabled).and_return([channel1, channel2])
      end

      it 'closes only up to the per-run limit across channels' do
        closed_conversation_ids = []
        allow_any_instance_of(Slack::Web::Client).to receive(:conversations_close) do |_client, channel:|
          closed_conversation_ids << channel
        end

        subject.send(:close_old_sups!)

        eligible_sups = [channel1_old_sup1, channel1_old_sup2, channel2_old_sup1, channel2_old_sup2]
        closed_sups = eligible_sups.count { |sup| sup.reload.closed_at.present? }

        expect(closed_conversation_ids.size).to eq 2
        expect(closed_conversation_ids - eligible_sups.map(&:conversation_id)).to be_empty
        expect(closed_sups).to eq 2
        expect(channel1_new_sup.reload.closed_at).to be_nil
        expect(channel2_new_sup.reload.closed_at).to be_nil
      end
    end
  end

  context 'export_data!' do
    include_context 'uses temp dir'

    let!(:export1) { Fabricate(:team_export) }
    let!(:export2) { Fabricate(:channel_export, exported: true) }

    it 'exports' do
      expect_any_instance_of(Export).to receive(:export!).once.and_call_original
      expect_any_instance_of(Export).to receive(:notify!)
      subject.send(:export_data!)
      expect(export1.reload.exported).to be true
    end
  end
end
