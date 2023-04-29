SlackRubyBotServer::Events.configure do |config|
  include SlackSup::Models::Mixins::Pluralize

  def parse_team_event(event)
    team = Team.where(team_id: event[:event][:team]).first || raise("Cannot find team with ID #{event[:event][:team]}.")
    data = Slack::Messages::Message.new(event[:event]).merge(team: team)
    return nil unless data.user == data.team.bot_user_id

    data
  end

  def parse_user_event(event)
    team = Team.where(team_id: event[:team_id]).first || raise("Cannot find team with ID #{event[:team_id]}.")
    Slack::Messages::Message.new(event[:event]).merge(team: team)
  end

  config.on :event, 'event_callback', 'member_joined_channel' do |event|
    data = parse_team_event(event)
    next { ok: false } unless data

    Api::Middleware.logger.info "#{data.team.name}: bot joined ##{data.channel}."
    data.team.join_channel!(data.channel, data.inviter)

    text =
      "Hi there! I'm your team's S'Up bot. " \
      "Thanks for trying me out. Type `#{data.team.bot_name} help` for instructions. " \
      "I plan to setup some S'Ups via Slack DM for all users in this channel next Monday. " \
      'You may want to `set size`, `set day`, `set timezone`, or `set sync now` users before then.'.freeze

    data.team.slack_client.chat_postMessage(channel: data.channel, text: text)

    { ok: true }
  end

  config.on :event, 'event_callback', 'member_left_channel' do |event|
    data = parse_team_event(event)
    next { ok: false } unless data

    Api::Middleware.logger.info "#{data.team.name}: bot left ##{data.channel}."
    data.team.leave_channel!(data.channel)

    { ok: true }
  end

  config.on :event, 'event_callback', 'app_home_opened' do |event|
    data = parse_user_event(event)
    next { ok: true } unless data && data.channel[0] == 'D'
    next { ok: true } if Sup.where(conversation_id: data.channel).any?

    channel = data.team.channels.where(channel_id: data.channel).first
    next { ok: true } if channel

    channel = data.team.channels.create!(channel_id: data.channel, enabled: false, sync: false, inviter_id: data.user)
    channel.users.create!(user_id: data.user, sync: false, enabled: false, opted_in: false)

    text = [
      "Hi there! I'm your team's S'Up bot.",
      data.team.channels.enabled.count > 0 ? "I connect your teammates in #{pluralize(data.team.channels.enabled.count, 'channel')}#{' (' + data.team.channels.enabled.map(&:slack_mention).and + ')'}." : 'Invite me to a channel so that I can connect you with others.',
      "You can opt out of S'Up by leaving a channel, or using `@sup opt out` in it.",
      'Type `help` for more options.'
    ].join(' ')

    Api::Middleware.logger.info "#{data.team.name}: user opened bot home ##{data.channel}."
    data.team.slack_client.chat_postMessage(channel: data.channel, text: text)

    { ok: true }
  end
end
