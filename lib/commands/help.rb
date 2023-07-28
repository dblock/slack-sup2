module SlackSup
  module Commands
    class Help < SlackRubyBotServer::Events::AppMentions::Mention
      mention 'help'

      HELP = <<~EOS.freeze
        ```
        Hi there! I'm your team's S'Up bot.

        The most valuable relationships are not made of two people, they’re made of three.

        In a DM
        -------
        help                       - this helpful message
        about                      - more helpful info about this bot
        stats                      - team stats
        opt [in|out] [#channel]    - opt in/out
        set                        - team settings
        next                       - time of all next rounds
        subscription               - show team subscription info
        unsubscribe                - cancel auto-renew, unsubscribe
        set api [on|off]           - enable/disable API access to your team data
        set api token              - require an access token in the X-Access-Token header for API access
        unset api token            - don't require an access token for API access
        rotate api token           - rotate the token required for API access

        In a Channel
        ------------
        stats                      - channel stats
        rounds [n]                 - channel stats for the last n rounds, default is 3
        next                       - time of next round
        set                        - show all channel settings

        In a Channel (Admins)
        --------------
        set size [number]          - set the number of people for each S'Up, default is 3
        set odd [yes/no]           - add one odd user to an existing S'Up and/or generate an additional smaller S'Up
        set day [day of week]      - set the day to S'Up, e.g. Tuesday or today, default is Monday
        set time [time of day]     - set the earliest time to S'Up, default is 9 AM
        set timezone [tz]          - set team timezone, default is Eastern Time (US & Canada)
        set weeks [number]         - set the number of weeks between S'Up, default is 1
        set followup [day of week] - set the follow up day of S'up, default is Thursday
        set recency [number]       - set the number of weeks during which to avoid pairing the same people, default is 12
        set opt [in|out]           - opt in (default) or opt out new users
        set sync [now]             - review or schedule a user sync from Slack
        sync                       - manually schedule a user sync (same as set sync now)
        set api [on|off]           - enable/disable API access to your channel data
        set api token              - require an access token in the X-Access-Token header for API access
        unset api token            - don't require an access token for API access
        rotate api token           - rotate the token required for API access
        set team field [name]      - set the name of the custom profile team field (users in the same team don't meet)
        unset team field           - unset the name of the custom profile team field
        set message [message]      - set the message users see when creating a S'Up DM
        unset message              - reset the message users see when creating a S'Up DM to the default one
        opt [in|out] [@mention]    - opt users in/out by @mention

        S'Up
        ----
        gcal [date/time]           - help me create a GCal (works inside a S'Up, eg. @sup gcal tomorrow 5pm)

        More information at https://sup2.playplay.io
        ```
      EOS
      def self.call(data)
        return if data.user == data.team.bot_user_id

        data.team.slack_client.chat_postMessage(channel: data.channel, text: [
          HELP,
          data.team.reload.subscribed? ? nil : data.team.trial_message
        ].compact.join("\n"))
        logger.info "HELP: #{data.team}, user=#{data.user}"
      end
    end
  end
end
