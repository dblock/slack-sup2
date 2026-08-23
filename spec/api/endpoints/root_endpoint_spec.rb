require 'spec_helper'

describe Api::Endpoints::RootEndpoint do
  include Api::Test::EndpointTest

  it 'hypermedia root' do
    get '/api'
    expect(last_response.status).to eq 200
    links = JSON.parse(last_response.body)['_links']
    expect(links.keys.sort).to eq(%w[self data round rounds stats status subscriptions channel channels credit_cards sup sups team teams user users].sort)
  end

  it 'preserves a reverse proxy path prefix in hypermedia links' do
    header 'X-Forwarded-Prefix', '/slack-sup2'
    get '/api'

    links = JSON.parse(last_response.body)['_links']
    expect(links['self']['href']).to eq 'http://example.org/slack-sup2/api'
    expect(links['status']['href']).to eq 'http://example.org/slack-sup2/api/status'

    get '/api/teams'

    links = JSON.parse(last_response.body)['_links']
    expect(links['self']['href']).to eq 'http://example.org/slack-sup2/api/teams'
  end

  it 'follows all links' do
    get '/api'
    expect(last_response.status).to eq 200
    links = JSON.parse(last_response.body)['_links']
    links.each_pair do |_key, h|
      href = h['href']
      next if href.include?('{') # templated link
      next if href == 'http://example.org/api/subscriptions'
      next if href == 'http://example.org/api/credit_cards'

      get href.gsub('http://example.org', '')
      expect(last_response.status).to eq 200
      expect(JSON.parse(last_response.body)).not_to eq({})
    end
  end

  it 'rewrites encoded HAL links to make them clickable' do
    get '/api/teams/%7B?cursor,size%7D'
    expect(last_response.status).to eq 302
    expect(last_response.headers['Location']).to eq '/api/teams/'
  end
end
