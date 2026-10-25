SlackRubyBotServer.configure do |config|
  config.oauth_version = :v2
  config.server_pages do |pages|
    pages.cache_control = 'private, no-cache'
  end
  config.oauth_scope = [
    'app_mentions:read',
    'channels:read',
    'chat:write',
    'groups:read',
    'im:history',
    'im:write',
    'mpim:history',
    'mpim:read',
    'mpim:write',
    'users:read',
    'users.profile:read',
    'users:read.email'
  ]
end
