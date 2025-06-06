module SlackSup
  module Commands
    class GCal < SlackRubyBotServer::Events::AppMentions::Mention
      include SlackSup::Commands::Mixins::Subscribe

      subscribe_command 'gcal' do |data|
        raise SlackSup::Error, 'Missing GOOGLE_API_CLIENT_ID.' unless ENV['GOOGLE_API_CLIENT_ID']

        sup = Sup.where(conversation_id: data.channel).desc(:_id).first
        raise SlackSup::Error, "Please `#{data.team.bot_name} gcal date/time` inside a S'Up DM channel." unless sup

        Chronic.time_class = sup.channel.sup_tzone
        dt = Chronic.parse(data.match['expression']) if data.match['expression']
        raise SlackSup::Error, "Please specify a date/time, eg. `#{data.team.bot_name} gcal tomorrow 5pm`." unless dt

        message = data.team.slack_client.chat_postMessage(
          channel: data.channel,
          text: "Click the button below to create a gcal for #{dt.strftime('%A, %B %d, %Y')} at #{dt.strftime('%l:%M %P').strip}.",
          attachments: [
            {
              text: '',
              attachment_type: 'default',
              actions: [
                {
                  type: 'button',
                  text: 'Add to Calendar',
                  url: sup.calendar_href(dt)
                }
              ]
            }
          ]
        )

        sup.update_attributes!(gcal_message_ts: message['ts'])
        logger.info "CALENDAR: #{data.team}, user=#{data.user}"
      end
    end
  end
end
