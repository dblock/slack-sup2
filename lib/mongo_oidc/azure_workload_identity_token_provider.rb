require 'json'
require 'net/http'
require 'uri'

module MongoOidc
  class TokenError < StandardError; end

  class AzureWorkloadIdentityTokenProvider
    DEFAULT_AUTHORITY_HOST = 'https://login.microsoftonline.com/'.freeze
    DEFAULT_SCOPE = 'https://ossrdbms-aad.database.windows.net/.default'.freeze
    DEFAULT_TIMEOUT_SECONDS = 10
    TOKEN_ASSERTION_TYPE = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'.freeze

    def initialize(environment: ENV, clock: -> { Time.now })
      @environment = environment
      @clock = clock
      @mutex = Mutex.new
    end

    def access_token
      @mutex.synchronize do
        return @access_token if cached_token_valid?

        response = request_token
        cache_token(response)
      end
    end

    def invalidate!
      @mutex.synchronize do
        @access_token = nil
        @expires_at = nil
      end
    end

    private

    def cached_token_valid?
      @access_token && @expires_at && @clock.call < @expires_at
    end

    def request_token
      uri = token_endpoint
      request = Net::HTTP::Post.new(uri)
      request['Content-Type'] = 'application/x-www-form-urlencoded'
      request.body = URI.encode_www_form(
        client_id: required_environment('AZURE_CLIENT_ID'),
        client_assertion: File.read(required_environment('AZURE_FEDERATED_TOKEN_FILE')).strip,
        client_assertion_type: TOKEN_ASSERTION_TYPE,
        grant_type: 'client_credentials',
        scope: @environment.fetch('MONGO_OIDC_TOKEN_SCOPE', DEFAULT_SCOPE)
      )

      timeout = Integer(@environment.fetch('MONGO_OIDC_TOKEN_TIMEOUT_SECONDS', DEFAULT_TIMEOUT_SECONDS))
      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == 'https',
        open_timeout: timeout,
        read_timeout: timeout
      ) do |http|
        http.request(request)
      end

      body = JSON.parse(response.body)
      unless response.is_a?(Net::HTTPSuccess)
        message = body['error_description'] || body['error'] || response.message
        raise TokenError, "Azure workload identity token request failed: #{message}"
      end

      body
    rescue JSON::ParserError => e
      raise TokenError, "Azure workload identity token response was not valid JSON: #{e.message}"
    rescue Errno::ENOENT => e
      raise TokenError, "Azure federated token file could not be read: #{e.message}"
    rescue ArgumentError => e
      raise TokenError, "Azure workload identity configuration is invalid: #{e.message}"
    end

    def cache_token(response)
      token = response.fetch('access_token')
      expires_in = Integer(response.fetch('expires_in'))
      raise TokenError, 'Azure workload identity token expiry must be positive.' unless expires_in.positive?

      refresh_buffer = [300, expires_in / 10].min
      @access_token = token
      @expires_at = @clock.call + expires_in - refresh_buffer
      @access_token
    rescue KeyError, ArgumentError => e
      raise TokenError, "Azure workload identity token response is incomplete: #{e.message}"
    end

    def token_endpoint
      authority_host = @environment.fetch('AZURE_AUTHORITY_HOST', DEFAULT_AUTHORITY_HOST)
      authority_host = "#{authority_host}/" unless authority_host.end_with?('/')
      URI.join(authority_host, "#{required_environment('AZURE_TENANT_ID')}/oauth2/v2.0/token")
    end

    def required_environment(name)
      value = @environment[name]
      raise TokenError, "Environment variable #{name} is required." if value.nil? || value.empty?

      value
    end
  end
end
