module SlackSup
  module Commands
    class Stats < SlackRubyBotServer::Events::AppMentions::Mention
      include SlackSup::Commands::Mixins::Channel

      VALID_PERIODS = %w[yearly monthly quarterly].freeze

      channel_command 'stats' do |channel, data|
        period = data.match['expression']&.strip&.downcase
        if period && !VALID_PERIODS.include?(period)
          data.team.slack_client.chat_postMessage(channel: data.channel, text: "Invalid period: #{period}. Use #{VALID_PERIODS.and}.")
        else
          stats = (channel || data.team).stats(period)
          data.team.slack_client.chat_postMessage(channel: data.channel, text: stats.to_s)
        end
        logger.info "STATS: #{data.team}, channel=#{data.channel}, user=#{data.user}"
      end
    end
  end
end
