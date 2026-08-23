require_relative 'mongo_oidc/azure_workload_identity_token_provider'
require_relative 'mongo_oidc/oidc'
require_relative 'mongo_oidc/driver_extension'

module MongoOidc
  class << self
    attr_writer :token_provider

    def token_provider
      @token_provider ||= AzureWorkloadIdentityTokenProvider.new
    end

    def reset_token_provider!
      @token_provider = nil
    end
  end
end

MongoOidc::DriverExtension.install!
