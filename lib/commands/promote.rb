module SlackSup
  module Commands
    class Promote < SlackRubyBotServer::Events::AppMentions::Mention
      include SlackSup::Commands::Mixins::User
      include SlackSup::Commands::Mixins::Subscribe

      user_command 'promote' do |channel, user, data|
        if channel
          raise SlackSup::Error, "Sorry, only #{channel.channel_admins_slack_mentions} can promote users." unless user.channel_admin?

          mention = data.match['expression']
          raise SlackSup::Error, 'Sorry, promote @someone.' if mention.blank?

          mentioned = channel.find_user_by_slack_mention!(mention)
          raise SlackSup::Error, 'Sorry, you cannot promote yourself.' if user == mentioned

          updated = !mentioned.is_admin
          mentioned.update_attributes!(is_admin: true) if updated
          data.team.slack_client.chat_postMessage(channel: data.channel, text: "User #{mentioned.slack_mention} is #{updated ? 'now' : 'already'} S'Up channel admin.")
          logger.info "PROMOTE: #{data.team}, #{mentioned}, is_admin=#{mentioned.is_admin}, channel=#{data.channel}, user=#{data.user}"
        else
          data.team.slack_client.chat_postMessage(channel: data.channel, text: 'Please run this command in a channel.')
        end
      end
    end
  end
end
