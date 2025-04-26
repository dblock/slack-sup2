module SlackSup
  module Commands
    class Vacation < SlackRubyBotServer::Events::AppMentions::Mention
      include SlackSup::Commands::Mixins::User
      include SlackSup::Commands::Mixins::Pluralize

      user_command 'vacation' do |channel, user, data|
        user_ids = []
        channel_ids = []
        op = nil
        rest = []

        parts = data.match['expression'].split(/\s+/) if data.match['expression']
        parts&.each do |part|
          if %w[until].include?(part)
            op = part
          elsif parsed_user = User.parse_slack_mention(part)
            user_ids << parsed_user
          elsif parsed_channel = Channel.parse_slack_mention(part)
            channel_ids << parsed_channel
          else
            rest << part
          end
        end

        if user_ids.any? && channel.nil?
          raise SlackSup::Error, "Sorry, only <@#{data.team.activated_user_id}> or a Slack team admin can see or change other users vacations." unless data.team.is_admin?(data.user)
        elsif channel && user && user_ids.any?
          raise SlackSup::Error, "Sorry, only #{channel.channel_admins_slack_mentions.or} can see or change other users vacations." unless user.channel_admin?
        elsif channel && user && channel_ids.any?
          raise SlackSup::Error, "Please DM #{data.team.bot_name} to change other users vacations." unless user.channel_admin?
        end

        user_ids << data.user if user_ids.none?
        channel_ids = data.team.channels.enabled.asc(:_id).map(&:channel_id) if channel_ids.none?
        rest = rest.join(' ') if rest

        messages = []

        user_ids.each do |user_id|
          results = []
          myself = (user_id == data.user)
          user_prefix = (myself ? 'You are' : "User <@#{user_id}> is").to_s

          channel_ids.each do |channel_id|
            channel = data.team.channels.where(channel_id:).first
            raise SlackSup::Error, "Sorry, I can't find an existing S'Up channel <##{channel_id}>." unless channel

            user = channel.users.where(user_id:).first
            next unless user && rest

            if rest == 'cancel' && user.vacation_until
              user.update_attributes!(vacation_until: nil)
              results << "#{user_prefix} now back from vacation in #{channel.slack_mention}."
            elsif rest == 'cancel'
              results << "#{user_prefix} not on vacation in #{channel.slack_mention}."
            elsif !rest.blank?
              vacation_until = Chronic.parse(rest, guess: false)
              raise SlackSup::Error, "Sorry, I don't understand who or what #{rest} is." unless vacation_until.is_a?(Range)

              vacation_until = op == 'until' ? vacation_until.first : vacation_until.last
              user.update_attributes!(vacation_until: vacation_until)
              results << "#{user_prefix} now on vacation in #{channel.slack_mention} until #{user.vacation_until_s}."
            elsif user.vacation_until
              results << "#{user_prefix} on vacation in #{channel.slack_mention} until #{user.vacation_until_s}."
            else
              results << "#{user_prefix} not on vacation in #{channel.slack_mention}."
            end
          end

          user_prefix = (myself ? 'You were' : "User <@#{user_id}> was").to_s
          results << "#{user_prefix} not found in any channels." if results.none?
          messages.concat(results)
        end

        messages << 'You were not found in any channels.' if messages.none?
        data.team.slack_client.chat_postMessage(channel: data.channel, text: messages.join("\n"))
        logger.info "VACATION: #{data.team}, for=#{user_ids.join(',')}, in=#{channel_ids.join(',')}, channel=#{data.channel}, user=#{data.user}, vacation=#{rest}"
      end
    end
  end
end
