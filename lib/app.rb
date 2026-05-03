module SlackSup
  class App < SlackRubyBotServer::App
    MAX_OLD_SUPS_TO_CLOSE_PER_RUN = 10

    def prepare!
      super
      deactivate_asleep_teams!
      cron!
    end

    def cron!
      logger.info 'Starting sup and subscription crons.'
      SlackRubyBotServer::Service.instance.tap do |instance|
        instance.once_and_every 60 * 60 * 24 * 3 do
          check_channel_auth!
          check_subscribed_teams!
          check_stripe_subscribers!
          check_expired_subscriptions!
        end
        instance.once_and_every 60 * 15 do
          leave!
          sync!
          sup!
        end
        instance.once_and_every 60 * 30 do
          remind!
          ask!
          ask_again!
          close_old_sups!
        end
        instance.once_and_every 60 do
          export_data!
        end
      end
    end

    private

    def check_channel_auth!
      Channel.enabled.each do |channel|
        channel.info
      rescue Slack::Web::Api::Errors::SlackError => e
        case e.message
        when 'is_archived', 'not_in_channel', 'account_inactive', 'channel_not_found', 'access_denied', 'invalid_auth'
          logger.warn "Channel info for #{channel} failed with #{e.message}, disabling."
          channel.update_attributes!(enabled: false)
        else
          logger.warn "Channel info for #{channel} failed with #{e.message}."
        end
      rescue StandardError => e
        logger.warn "Channel info for #{channel} failed with an unexpected error, #{e.message}."
      end
    end

    def invoke_with_criteria!(obj, &)
      obj.each do |obj|
        yield obj
      rescue StandardError => e
        backtrace = e.backtrace.join("\n")
        logger.warn "Error in cron for #{obj}, #{e.message}, #{backtrace}."
      end
    end

    def invoke!(&)
      invoke_with_criteria!(Channel.enabled, &)
    end

    def ask!
      invoke! do |channel|
        last_round_at = channel.last_round_at
        logger.info "Checking whether to ask #{channel}, #{last_round_at ? 'last round ' + last_round_at.ago_in_words : 'first time sup'}."
        round = channel.ask!
        logger.info "Asked about previous sup round #{round}." if round
      end
    end

    def ask_again!
      invoke! do |channel|
        last_round_at = channel.last_round_at
        logger.info "Checking whether to ask again #{channel}, #{last_round_at ? 'last round ' + last_round_at.ago_in_words : 'first time sup'}."
        round = channel.ask_again!
        logger.info "Asked again about previous sup round #{round}." if round
      end
    end

    def remind!
      invoke! do |channel|
        last_round_at = channel.last_round_at
        logger.info "Checking whether to remind #{channel}, #{last_round_at ? 'last round ' + last_round_at.ago_in_words : 'first time sup'}."
        round = channel.remind!
        logger.info "Reminded about previous sup round #{round}." if round
      end
    end

    def sync!
      invoke_with_criteria!(Team.active) do |team|
        tt = Time.now.utc
        team.sync!
        logger.info "Synced #{team}, #{team.users.where(channel_id: nil, :updated_at.gte => tt).count} user(s) updated."
      end

      invoke_with_criteria!(Channel.enabled.where(sync: true)) do |channel|
        tt = Time.now.utc
        channel.sync!
        logger.info "Synced #{channel}, #{channel.users.where(:updated_at.gte => tt).count} user(s) updated."
      end
    end

    def leave!
      invoke! do |channel|
        next if channel.bot_in_channel?

        logger.info "Removing bot from #{channel}."
        channel.leave!
      end
    end

    def sup!
      invoke! do |channel|
        last_round_at = channel.last_round_at
        logger.info "Checking whether to sup #{channel}, #{last_round_at ? 'last round ' + last_round_at.ago_in_words : 'first time sup'}."
        next unless channel.sup?

        round = channel.sup!
        logger.info "Created sup round #{round}."
      end
    end

    def check_expired_subscriptions!
      Team.active.where(subscribed: false).each do |team|
        if team.trial?
          remaining_trial_days = team.remaining_trial_days
          logger.info "Team #{team} created #{team.created_at.ago_in_words}, trial ends in #{remaining_trial_days} day#{'s' unless remaining_trial_days == 1}."
        elsif team.subscription_expired?
          logger.info "Team #{team} created #{team.created_at.ago_in_words}, subscription has expired."
          team.inform! team.subscribe_text
        end
      end
    end

    def deactivate_asleep_teams!
      Team.active.each do |team|
        next unless team.asleep?

        begin
          team.deactivate!
          team.inform! "The S'Up bot hasn't been used for 3 weeks, deactivating. Reactivate at #{SlackRubyBotServer::Service.url}. Your data will be purged in another 2 weeks."
        rescue StandardError => e
          logger.warn "Error informing team #{team}, #{e.message}."
        end
      end
    end

    def check_stripe_subscribers!
      Stripe::Subscription.list(plan: 'slack-sup2-yearly').auto_paging_each do |subscription|
        customer = Stripe::Customer.retrieve(subscription.customer)
        metadata = customer.metadata

        team = Team.where(stripe_customer_id: subscription.customer).first
        team ||= Team.where(team_id: metadata.team_id).first

        next if team&.subscribed? && team.active?

        if team
          if team.active?
            logger.warn "Re-associating customer_id for #{metadata.name} (#{metadata.team_id}) with #{team}."
            team.update_attributes!(stripe_customer_id: subscription.customer, subscribed: true)
          elsif team.active_stripe_subscription
            logger.warn "Inactive team #{team} for #{metadata.name} (#{metadata.team_id})."
            active_subscription = team.active_stripe_subscription
            Stripe::Subscription.update(active_subscription.id, cancel_at_period_end: true)
            amount = ActiveSupport::NumberHelper.number_to_currency(active_subscription.plan.amount.to_f / 100)
            logger.warn "Successfully canceled auto-renew for #{active_subscription.plan.name} (#{amount}) for #{team}."
          else
            logger.warn "Inactive team #{team} for #{metadata.name} (#{metadata.team_id}), no active subscription to cancel."
          end
        else
          logger.warn "Cannot find team for #{metadata.name} (#{metadata.team_id}), contact #{customer.email}."
        end
      rescue StandardError => e
        logger.warn "Error checking customer #{subscription.customer}, #{e.message}."
      end
    end

    def check_subscribed_teams!
      Team.where(subscribed: true, :stripe_customer_id.ne => nil).each do |team|
        customer = Stripe::Customer.retrieve(team.stripe_customer_id)
        customer.subscriptions.each do |subscription|
          subscription_name = "#{subscription.plan.name} (#{ActiveSupport::NumberHelper.number_to_currency(subscription.plan.amount.to_f / 100)})"
          logger.info "Checking #{team} subscription to #{subscription_name}, #{subscription.status}."
          case subscription.status
          when 'past_due'
            next if team.past_due_informed_at && Time.now.utc < team.past_due_informed_at + 72.hours

            logger.warn "Subscription for #{team} is #{subscription.status}, notifying."
            team.inform! "Your subscription to #{subscription_name} is past due. #{team.update_cc_text}"
            team.update_attributes!(past_due_informed_at: Time.now.utc)
          when 'canceled', 'unpaid'
            logger.warn "Subscription for #{team} is #{subscription.status}, downgrading."
            team.inform! "Your subscription to #{subscription.plan.name} (#{ActiveSupport::NumberHelper.number_to_currency(subscription.plan.amount.to_f / 100)}) was canceled and your team has been downgraded. Thank you for being a customer!"
            team.update_attributes!(subscribed: false, past_due_informed_at: nil)
          end
        end
        if customer.subscriptions.none?
          logger.info "No active subscriptions for #{team} (#{team.stripe_customer_id}), downgrading."
          team.inform! 'Your subscription was canceled and your team has been downgraded. Thank you for being a customer!'
          team.update_attributes!(subscribed: false)
        end
      rescue StandardError => e
        logger.warn "Error informing team #{team}, #{e.message}."
      end
    end

    def export_data!
      invoke_with_criteria!(Export.requested) do |export|
        export.export!
      end
    end

    def close_old_sups!
      closed_counts = Hash.new(0)
      invoke_with_criteria!(closeable_old_sups(limit: MAX_OLD_SUPS_TO_CLOSE_PER_RUN)) do |sup|
        sup.close!
        closed_counts[sup.channel] += 1
      end
      closed_counts.each do |channel, count|
        logger.info "Closed #{count} old DM conversation(s) for #{channel}."
      end
    end

    def closeable_old_sups(limit:)
      old_sups = []
      Channel.enabled.each do |channel|
        break if old_sups.size >= limit

        old_sups.concat(channel.closeable_old_sups(limit: limit - old_sups.size))
      rescue StandardError => e
        backtrace = e.backtrace.join("\n")
        logger.warn "Error in cron for #{channel}, #{e.message}, #{backtrace}."
      end
      old_sups
    end
  end
end
