SlackRubyBotServer::Events.configure do |config|
  config.on :action, 'interactive_message' do |action|
    payload = action[:payload]
    error! 'Missing actions.', 400 unless payload[:actions]
    error! 'Missing action.', 400 unless payload[:actions].first

    case payload[:actions].first[:name]
    when 'outcome'
      sup = Sup.find(payload[:callback_id]) || error!('Sup Not Found', 404)
      sup.update_attributes!(outcome: payload[:actions].first[:value])

      owner = sup.channel ? "channel #{sup.channel}" : "team #{sup.team}"
      Api::Middleware.logger.info "Updated #{owner}, sup #{sup} outcome to '#{sup.outcome}'."

      message = Sup::ASK_WHO_SUP_MESSAGE.dup

      message[:attachments].first[:callback_id] = sup.id.to_s
      message[:attachments].first[:actions].each do |a|
        a[:style] = a[:value] == sup.outcome ? 'primary' : 'default'
      end

      message[:text] = Sup::RESPOND_TO_ASK_MESSAGES[sup.outcome]

      Faraday.post(payload[:response_url], {
        response_type: 'in_channel',
        thread_ts: payload[:original_message][:ts]
      }.merge(message).to_json, 'Content-Type' => 'application/json')
      sup.notify_suggested_by!
    end

    false
  end
end
