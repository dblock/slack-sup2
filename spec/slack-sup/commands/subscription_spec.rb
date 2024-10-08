require 'spec_helper'

describe SlackSup::Commands::Subscription do
  shared_examples_for 'subscription' do
    include_context 'stripe mock'
    context 'with a plan' do
      before do
        stripe_helper.create_plan(id: 'slack-sup2-yearly', amount: 3999)
      end

      context 'a customer' do
        let!(:customer) do
          Stripe::Customer.create(
            source: stripe_helper.generate_card_token,
            plan: 'slack-sup2-yearly',
            email: 'foo@bar.com'
          )
        end

        before do
          allow_any_instance_of(Team).to receive(:short_lived_token).and_return('token')
          team.update_attributes!(subscribed: true, stripe_customer_id: customer['id'])
        end

        context 'active subscription' do
          let(:active_subscription) { team.active_stripe_subscription }
          let(:current_period_end) { Time.at(active_subscription.current_period_end).strftime('%B %d, %Y') }

          it 'displays subscription info' do
            customer_info = "Customer since #{Time.at(customer.created).strftime('%B %d, %Y')}."
            customer_info += "\nSubscribed to StripeMock Default Plan ID ($39.99), will auto-renew on #{current_period_end}."
            card = customer.sources.first
            customer_info += "\nOn file Visa card, #{card.name} ending with #{card.last4}, expires #{card.exp_month}/#{card.exp_year}."
            customer_info += "\n#{team.update_cc_text}"
            expect(message: '@sup subscription', channel: 'DM').to respond_with_slack_message customer_info
          end

          it 'requires an admin user' do
            allow_any_instance_of(Team).to receive(:is_admin?).and_return(false)
            expect(message: '@sup subscription', channel: 'DM').to respond_with_slack_message "Only <@#{team.activated_user_id}> or a Slack team admin can get subscription details, sorry."
          end
        end

        context 'past due subscription' do
          before do
            customer.subscriptions.data.first['status'] = 'past_due'
            allow(Stripe::Customer).to receive(:retrieve).and_return(customer)
          end

          it 'displays subscription info' do
            customer_info = "Customer since #{Time.at(customer.created).strftime('%B %d, %Y')}."
            customer_info += "\nPast Due subscription created November 03, 2016 to StripeMock Default Plan ID ($39.99)."
            card = customer.sources.first
            customer_info += "\nOn file Visa card, #{card.name} ending with #{card.last4}, expires #{card.exp_month}/#{card.exp_year}."
            customer_info += "\n#{team.update_cc_text}"
            expect(message: '@sup subscription', channel: 'DM').to respond_with_slack_message customer_info
          end

          it 'requires an admin user' do
            allow_any_instance_of(Team).to receive(:is_admin?).and_return(false)
            expect(message: '@sup subscription', channel: 'DM').to respond_with_slack_message "Only <@#{team.activated_user_id}> or a Slack team admin can get subscription details, sorry."
          end
        end
      end
    end
  end

  context 'unsubscribed team' do
    include_context 'team'

    it 'is a subscription feature' do
      expect(message: '@sup subscription', channel: 'DM').to respond_with_slack_message(
        "Subscribe your team for $39.99 a year at #{SlackRubyBotServer::Service.url}/subscribe?team_id=#{team.team_id}."
      )
    end
  end

  context 'subscribed team' do
    let!(:team) { Fabricate(:team, subscribed: true) }

    context 'as admin' do
      before do
        allow_any_instance_of(Team).to receive(:is_admin?).and_return(true)
      end

      context 'subscribed team without a customer ID' do
        before do
          team.update_attributes!(stripe_customer_id: nil)
        end

        it 'reports subscribed' do
          expect(message: '@sup subscription', channel: 'DM').to respond_with_slack_message(
            'Team is subscribed.'
          )
        end
      end

      context 'subscribed since' do
        before do
          team.update_attributes!(subscribed_at: team.created_at)
        end

        it 'reports subscribed' do
          expect(message: '@sup subscription', channel: 'DM').to respond_with_slack_message(
            "Subscriber since #{team.subscribed_at.strftime('%B %d, %Y')}."
          )
        end
      end

      it_behaves_like 'subscription'
      context 'with another team' do
        let!(:team2) { Fabricate(:team) }

        it_behaves_like 'subscription'
      end
    end
  end
end
