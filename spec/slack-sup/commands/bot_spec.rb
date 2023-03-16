require 'spec_helper'

describe SlackSup::Commands do
  context 'subscribed team' do
    include_context :subscribed_team

    it 'ignores bot loop commands' do
      expect(message: '@sup stats', user: team.bot_user_id).to_not respond_with_slack_message
    end
  end
end
