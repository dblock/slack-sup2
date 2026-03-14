Fabricator(:sup) do
  round { Round.first || Fabricate(:round) }
  channel { Team.first&.channels&.first || Fabricate(:channel) }
  team { |attrs| attrs[:channel]&.team || attrs[:round]&.channel&.team || Team.first || Fabricate(:team) }
end
