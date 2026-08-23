require 'spec_helper'

describe MongoOidc::DriverExtension do
  let(:token_provider) { instance_double(MongoOidc::AzureWorkloadIdentityTokenProvider, access_token: 'access-token') }

  before do
    MongoOidc.token_provider = token_provider
  end

  after do
    MongoOidc.reset_token_provider!
  end

  it 'registers MONGODB-OIDC with the Mongo Ruby driver' do
    expect(Mongo::Auth::SOURCES[:mongodb_oidc]).to eq Mongo::Auth::Oidc
    expect(Mongo::URI::AUTH_MECH_MAP['MONGODB-OIDC']).to eq :mongodb_oidc
  end

  it 'uses the external authentication source by default' do
    user = Mongo::Auth::User.new(auth_mech: :mongodb_oidc)

    expect(user.auth_source).to eq '$external'
  end

  it 'encodes the access token in a JwtStepRequest BSON payload' do
    user = Mongo::Auth::User.new(auth_mech: :mongodb_oidc)
    conversation = Mongo::Auth::Oidc::Conversation.new(user, nil)
    payload = conversation.send(:client_first_payload)
    document = BSON::Document.from_bson(BSON::ByteBuffer.new(payload))

    expect(document).to eq BSON::Document.new(jwt: 'access-token')
  end

  it 'accepts an OIDC URI without a username or password' do
    client = Mongo::Client.new(
      'mongodb://localhost/slack_sup2_test?authMechanism=MONGODB-OIDC',
      connect: :direct
    )

    expect(client.options[:auth_mech]).to eq :mongodb_oidc
    expect(client.options[:auth_source]).to eq '$external'
  ensure
    client&.close
  end

  it 'rejects passwords for OIDC authentication' do
    expect do
      Mongo::Client.new(
        'mongodb://user:password@localhost/slack_sup2_test?authMechanism=MONGODB-OIDC',
        connect: :direct
      )
    end.to raise_error(Mongo::Auth::InvalidConfiguration, 'Password is not supported for MONGODB-OIDC.')
  end
end
