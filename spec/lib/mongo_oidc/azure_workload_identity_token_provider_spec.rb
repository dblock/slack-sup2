require 'spec_helper'
require 'fileutils'
require 'tmpdir'

describe MongoOidc::AzureWorkloadIdentityTokenProvider do
  let(:token_file) { File.join(Dir.tmpdir, "slack-sup2-oidc-#{Process.pid}") }
  let(:clock) { Time.utc(2026, 8, 23, 0, 0, 0) }
  let(:environment) do
    {
      'AZURE_AUTHORITY_HOST' => 'https://login.microsoftonline.test',
      'AZURE_CLIENT_ID' => 'client-id',
      'AZURE_FEDERATED_TOKEN_FILE' => token_file,
      'AZURE_TENANT_ID' => 'tenant-id'
    }
  end
  let(:provider) { described_class.new(environment: environment, clock: -> { clock }) }
  let(:token_url) { 'https://login.microsoftonline.test/tenant-id/oauth2/v2.0/token' }

  before do
    File.write(token_file, 'federated-token')
  end

  after do
    FileUtils.rm_f(token_file)
  end

  it 'exchanges the projected service account token for a MongoDB access token' do
    request = stub_request(:post, token_url)
              .with(
                body: hash_including(
                  'client_assertion' => 'federated-token',
                  'client_id' => 'client-id',
                  'grant_type' => 'client_credentials',
                  'scope' => described_class::DEFAULT_SCOPE
                )
              )
              .to_return(
                status: 200,
                body: { access_token: 'access-token', expires_in: 3600 }.to_json,
                headers: { 'Content-Type' => 'application/json' }
              )

    expect(provider.access_token).to eq 'access-token'
    expect(provider.access_token).to eq 'access-token'
    expect(request).to have_been_requested.once
  end

  it 'requests a new token after invalidation' do
    request = stub_request(:post, token_url)
              .to_return(
                status: 200,
                body: { access_token: 'access-token', expires_in: 3600 }.to_json,
                headers: { 'Content-Type' => 'application/json' }
              )

    provider.access_token
    provider.invalidate!
    provider.access_token

    expect(request).to have_been_requested.twice
  end

  it 'raises a descriptive error when workload identity is not configured' do
    environment.delete('AZURE_CLIENT_ID')

    expect { provider.access_token }
      .to raise_error(MongoOidc::TokenError, 'Environment variable AZURE_CLIENT_ID is required.')
  end

  it 'does not expose tokens in an unsuccessful response error' do
    stub_request(:post, token_url)
      .to_return(
        status: 401,
        body: { error: 'invalid_client', error_description: 'workload identity rejected' }.to_json,
        headers: { 'Content-Type' => 'application/json' }
      )

    expect { provider.access_token }
      .to raise_error(MongoOidc::TokenError, 'Azure workload identity token request failed: workload identity rejected')
  end
end
