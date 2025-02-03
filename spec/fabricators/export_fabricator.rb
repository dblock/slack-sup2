Fabricator(:export) do
  user_id { Fabricate.sequence(:user_id) { |i| "U#{i}" } }
end

Fabricator(:team_export, from: :export) do
  team { Team.first || Fabricate(:team) }
end

Fabricator(:channel_export, from: :export) do
  channel { Channel.first || Fabricate(:channel) }

  before_create do
    self.team ||= channel.team
  end
end
