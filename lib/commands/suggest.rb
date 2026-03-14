module SlackSup
  module Commands
    class Suggest < SlackRubyBotServer::Events::AppMentions::Mention
      include SlackSup::Commands::Mixins::User

      user_command 'suggest' do |_channel, user, data|
        mentions, suggested_text = parse_expression(data.match['expression'])
        raise SlackSup::Error, 'Sorry, suggest [@user ...] [what to talk about].' if mentions.size < 2

        suggested_users = mentions.uniq.map { |mention| data.team.find_or_create_user!(User.parse_slack_mention!(mention)) }
        raise SlackSup::Error, 'Sorry, you cannot suggest a S\'Up for yourself.' if suggested_users.any? { |suggested_user| suggested_user.user_id == user.user_id }

        sup = Sup.create!(team: data.team, users: suggested_users, suggested_by: user, suggested_text:)
        sup.sup!

        data.team.slack_client.chat_postMessage(channel: data.channel, text: "Suggested a S'Up for #{suggested_users.map(&:slack_mention).and}.")
        logger.info "SUGGEST: #{data.team}, channel=#{data.channel}, suggested_by=#{data.user}, users=#{suggested_users.map(&:user_id).join(',')}"
      rescue StandardError
        sup&.destroy if sup&.conversation_id.nil?
        raise
      end

      def self.parse_expression(expression)
        return [[], nil] if expression.blank?

        parts = expression.split(/\s+/)
        mentions = []
        mentions << parts.shift while parts.first && User.parse_slack_mention(parts.first)
        [mentions, parts.join(' ').presence]
      end
    end
  end
end
