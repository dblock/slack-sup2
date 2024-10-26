module SlackSup
  module Models
    module Mixins
      module ShortLivedToken
        extend ActiveSupport::Concern

        def short_lived_token
          JWT.encode({ dt: Time.now.utc.to_i, nonce: SecureRandom.hex }, token)
        end

        def short_lived_token_valid?(short_lived_token, dt = 30.minutes)
          return false unless short_lived_token

          data, = JWT.decode(short_lived_token, token)
          Time.at(data['dt']).utc + dt >= Time.now.utc
        rescue JWT::DecodeError
          false
        end
      end
    end
  end
end
