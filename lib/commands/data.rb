module SlackSup
  module Commands
    class Data < SlackRubyBotServer::Events::AppMentions::Mention
      include SlackSup::Commands::Mixins::User

      class << self
        def parse_number_of_rounds(m)
          return 1 unless m

          m.downcase == 'all' ? nil : Integer(m)
        end

        def parse_expression(expression)
          parts = expression.split(/\s+/, 2)
          channel = Channel.parse_slack_mention(parts.first)
          parts.shift if channel
          rounds = parse_number_of_rounds(parts.first)
          [channel, rounds]
        end

        def access_target_channel(team, target, user)
          channel = team.channels.where(channel_id: target).first
          if channel.nil?
            raise SlackSup::Error, "Sorry, <##{target}> is not a S'Up channel."
          elsif !channel.is_admin?(user)
            raise SlackSup::Error, "Sorry, only admins of #{channel.slack_mention}, <@#{team.activated_user_id}>, or a Slack team admin can download channel data."
          else
            channel
          end
        end
      end

      user_command 'data' do |channel, user, data|
        target, rounds = if data.match['expression']
                           parse_expression(data.match['expression'])
                         else
                           [nil, 1]
                         end

        raise SlackSup::Error, "Sorry, #{rounds} is not a valid number of rounds." unless rounds.nil? || rounds&.positive?

        channel = access_target_channel(data.team, target, user) if target

        if channel
          raise SlackSup::Error, "Sorry, only #{channel.channel_admins_slack_mentions.or} can download raw data." unless channel.is_admin?(user)
          raise SlackSup::Error, "Sorry, I didn't find any rounds, try `all` to get all data." if rounds && rounds >= 0 && channel.rounds.empty?
          raise SlackSup::Error, "Sorry, I only found #{pluralize(channel.rounds.size, 'round')}, try 1, #{channel.rounds.size} or `all`." if rounds && channel.rounds.count < rounds
          raise SlackSup::Error, "Hey <@#{data.user}>, we are still working on your previous request." if Export.where(team: data.team, channel: channel, user_id: data.user, exported: false).exists?

          Export.create!(
            team: data.team,
            channel: channel,
            user_id: data.user,
            max_rounds_count: rounds
          )

          rounds_s = if rounds == 1
                       'the most recent round'
                     elsif rounds&.positive?
                       "#{rounds} most recent rounds"
                     elsif rounds.nil?
                       'all rounds'
                     else
                       pluralize(channel.rounds.size, 'most recent round')
                     end

          data.team.slack_client.chat_postMessage(
            channel: data.channel,
            text: "Hey <@#{data.user}>, we will prepare your #{channel.slack_mention} channel data for #{rounds_s} in the next few minutes, please check your DMs for a link."
          )

          logger.info "DATA: #{data.team}, channel=#{data.channel}, user=#{data.user}, rounds=#{rounds}"
        else
          raise SlackSup::Error, "Sorry, only <@#{data.team.activated_user_id}> or a Slack team admin can download raw data." unless data.team.is_admin?(data.user)
          raise SlackSup::Error, "Sorry, I didn't find any rounds, try `all` to get all data." if rounds && rounds >= 0 && data.team.rounds.empty?
          raise SlackSup::Error, "Sorry, I only found #{pluralize(data.team.max_rounds_count, 'round')}, try 1, #{data.team.max_rounds_count} or `all`." if rounds && data.team.max_rounds_count < rounds
          raise SlackSup::Error, "Hey <@#{data.user}>, we are still working on your previous request." if Export.where(team: data.team, channel: nil, user_id: data.user, exported: false).exists?

          Export.create!(
            team: data.team,
            user_id: data.user,
            max_rounds_count: rounds
          )

          rounds_s = if rounds == 1
                       'the most recent round'
                     elsif rounds&.positive?
                       "#{rounds} most recent rounds"
                     else
                       'all rounds'
                     end

          data.team.slack_client.chat_postMessage(
            channel: data.channel,
            text: "Hey <@#{data.user}>, we will prepare your team data for #{rounds_s} in the next few minutes, please check your DMs for a link."
          )

          logger.info "DATA: #{data.team}, user=#{data.user}, rounds=#{rounds}"
        end
      end
    end
  end
end
