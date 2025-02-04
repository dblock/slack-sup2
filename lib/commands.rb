require_relative 'commands/mixins'
require_relative 'commands/help'
require_relative 'commands/about'
require_relative 'commands/admins'
require_relative 'commands/subscription'
require_relative 'commands/unsubscribe'
require_relative 'commands/opt'
require_relative 'commands/set'
require_relative 'commands/stats'
require_relative 'commands/next'
require_relative 'commands/rounds'
require_relative 'commands/gcal'
require_relative 'commands/sync'
require_relative 'commands/promote'
require_relative 'commands/demote'
require_relative 'commands/data'

SlackRubyBotServer::Events::AppMentions.configure do |config|
  config.handlers = [
    SlackSup::Commands::Help,
    SlackSup::Commands::About,
    SlackSup::Commands::Admins,
    SlackSup::Commands::Subscription,
    SlackSup::Commands::Unsubscribe,
    SlackSup::Commands::Set,
    SlackSup::Commands::Opt,
    SlackSup::Commands::Stats,
    SlackSup::Commands::Next,
    SlackSup::Commands::Rounds,
    SlackSup::Commands::GCal,
    SlackSup::Commands::Sync,
    SlackSup::Commands::Promote,
    SlackSup::Commands::Demote,
    SlackSup::Commands::Data
  ]
end
