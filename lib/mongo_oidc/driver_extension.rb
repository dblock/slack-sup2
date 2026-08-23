module MongoOidc
  module DriverExtension
    module ClientAuthenticationValidation
      private

      def validate_authentication_options!
        return super unless options[:auth_mech] == :mongodb_oidc

        raise Mongo::Auth::InvalidConfiguration, 'Password is not supported for MONGODB-OIDC.' if options[:password]

        raise Mongo::Auth::InvalidConfiguration, 'MONGODB-OIDC requires authSource=$external.' unless [nil, Mongo::Auth::EXTERNAL].include?(options[:auth_source])

        properties = options[:auth_mech_properties]
        return if properties.nil? || properties.empty?

        raise Mongo::Auth::InvalidConfiguration,
              'authMechanismProperties are not supported by the Azure workload identity integration.'
      end
    end

    module UserDefaults
      def default_auth_source(options)
        return Mongo::Auth::EXTERNAL if options[:auth_mech] == :mongodb_oidc

        super
      end
    end

    class << self
      def install!
        return if Mongo::Auth::SOURCES.key?(:mongodb_oidc)

        install_uri_mapping
        Mongo::Auth::SOURCES[:mongodb_oidc] = Mongo::Auth::Oidc
        Mongo::Client.prepend(ClientAuthenticationValidation)
        Mongo::Auth::User.singleton_class.prepend(UserDefaults)
      end

      private

      def install_uri_mapping
        mapping = Mongo::URI::AUTH_MECH_MAP.merge('MONGODB-OIDC' => :mongodb_oidc).freeze
        Mongo::URI.send(:remove_const, :AUTH_MECH_MAP)
        Mongo::URI.const_set(:AUTH_MECH_MAP, mapping)
      end
    end
  end
end
