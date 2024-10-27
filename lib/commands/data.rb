module SlackSup
  module Commands
    class Data < SlackRubyBotServer::Events::AppMentions::Mention
      include SlackSup::Commands::Mixins::User

      user_command 'data' do |channel, user, data|
        if channel
          raise SlackSup::Error, "Sorry, only #{channel.channel_admins_slack_mentions} can download raw data." unless user.channel_admin?

          dm = data.team.slack_client.conversations_open(users: data.user)
          data.team.slack_client.chat_postMessage(
            channel: dm.channel.id,
            text: "Click here to download your #{channel.slack_mention} channel data.",
            attachments: [
              {
                text: '',
                attachment_type: 'default',
                actions: [
                  {
                    type: 'button',
                    text: 'Download',
                    url: "#{SlackRubyBotServer::Service.url}/api/data?team_id=#{channel.team.id}&channel_id=#{channel.id}&access_token=#{CGI.escape(channel.short_lived_token)}"
                  }
                ]
              }
            ]
          )

          data.team.slack_client.chat_postMessage(channel: data.channel, text: "Hey <@#{data.user}>, check your DMs for a link.")

          logger.info "DATA: #{data.team}, channel=#{data.channel}, user=#{data.user}"
        else
          raise SlackSup::Error, "Sorry, only <@#{data.team.activated_user_id}> or a Slack team admin can download raw data." unless data.team.is_admin?(data.user)

          data.team.slack_client.chat_postMessage(
            channel: data.channel,
            text: 'Click here to download your team data.',
            attachments: [
              {
                text: '',
                attachment_type: 'default',
                actions: [
                  {
                    type: 'button',
                    text: 'Download',
                    url: "#{SlackRubyBotServer::Service.url}/api/data?team_id=#{data.team.id}&access_token=#{CGI.escape(data.team.short_lived_token)}"
                  }
                ]
              }
            ]
          )

          logger.info "DATA: #{data.team}, user=#{data.user}"
        end
      end
    end
  end
end
