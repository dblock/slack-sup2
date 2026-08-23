module Mongo
  module Auth
    class Oidc < Base
      MECHANISM = 'MONGODB-OIDC'.freeze

      def login
        attempts = 0

        begin
          attempts += 1
          response = converse_1_step(connection, conversation)
          return response if response[:done]

          raise Mongo::Error::InvalidServerAuthResponse,
                'Server did not complete the MONGODB-OIDC conversation.'
        rescue Mongo::Auth::Unauthorized
          raise if attempts >= 2

          MongoOidc.token_provider.invalidate!
          @conversation = nil
          retry
        end
      end

      class Conversation < SaslConversationBase
        private

        def client_first_payload
          { jwt: MongoOidc.token_provider.access_token }.to_bson.to_s
        end
      end
    end
  end
end
