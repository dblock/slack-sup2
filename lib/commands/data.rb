module SlackSup
  module Commands
    class Data < SlackRubyBotServer::Events::AppMentions::Mention
      include SlackSup::Commands::Mixins::User

      class << self
        def parse_expression(m)
          expression = m['expression']
          Channel.parse_slack_mention(expression.split(/\s+/, 2).first)
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
        target = parse_expression(data.match) if data.match['expression']
        channel = access_target_channel(data.team, target, user) if target

        if channel
          raise SlackSup::Error, "Sorry, only #{channel.channel_admins_slack_mentions} can download raw data." unless channel.is_admin?(user)

          channel_id = data.channel[0] == 'D' ? data.channel : data.team.slack_client.conversations_open(users: data.user).channel.id

          data.team.slack_client.chat_postMessage(
            channel: channel_id,
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

          data.team.slack_client.chat_postMessage(channel: data.channel, text: "Hey <@#{data.user}>, check your DMs for a link.") unless data.channel[0] == 'D'

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
