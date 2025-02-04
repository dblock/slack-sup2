module SlackSup
  module Commands
    class Admins < SlackRubyBotServer::Events::AppMentions::Mention
      include SlackSup::Commands::Mixins::User

      user_command 'admins' do |channel, _user, data|
        if channel
          admins = channel.channel_admins_slack_mentions
          data.team.slack_client.chat_postMessage(channel: data.channel, text: "Channel #{admins.size == 1 ? 'admin is' : 'admins are'} #{admins.and}.")
          logger.info "ADMINS: #{data.team}, channel=#{data.channel}, user=#{data.user}"
        else
          data.team.slack_client.chat_postMessage(channel: data.channel, text: "Team admin is <@#{data.team.activated_user_id}>.")
          logger.info "ADMINS: #{data.team}, user=#{data.user}"
        end
      end
    end
  end
end
