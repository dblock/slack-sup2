RSpec.shared_context 'subscribed team' do
  let!(:team) { Fabricate(:team, subscribed: true) }
end

RSpec.shared_context 'team' do
  let!(:team) { Fabricate(:team) }
end

RSpec.shared_context 'channel' do
  include_context 'subscribed team'
  let!(:channel) { Fabricate(:channel, channel_id: 'channel', sup_wday: Date::MONDAY, sup_followup_wday: Date::THURSDAY) }
end

RSpec.shared_context 'user' do
  include_context 'channel'

  let!(:user) { Fabricate(:user, channel:, user_name: 'username') }
end
