require 'spec_helper'

describe Api::Middleware do
  include Rack::Test::Methods

  let(:app) { described_class.instance }

  ['/', '/help.html', '/privacy.html', '/subscribe.html', '/update_cc.html', '/gcal.html'].each do |path|
    it "serves #{path} with versioned local assets and a revalidating cache policy" do
      get path

      assets = Capybara.string(last_response.body).all('script[src^="/"], link[href^="/"], img[src^="/"], meta[name="msapplication-TileImage"]', visible: :all)
      expect(last_response.status).to eq 200
      expect(assets).not_to be_empty
      expect(assets.map { |asset| asset[:src] || asset[:href] || asset[:content] }).to all(match(/\?v=[a-f0-9]{64}\z/))
      expect(last_response.headers['Cache-Control']).to eq 'private, no-cache'
    end
  end

  it 'renders a revalidating stylesheet with a versioned background image' do
    get '/styles.css'

    expect(last_response.content_type).to eq 'text/css; charset=utf-8'
    expect(last_response.headers['Cache-Control']).to eq 'private, no-cache'
    expect(last_response.body).to include("/img/screenshot-background.svg?v=#{Digest::SHA256.file('public/img/screenshot-background.svg').hexdigest}")
  end

  it 'versions Stripe checkout images in both JavaScript and data attributes' do
    icon_path = "/img/icon.png?v=#{Digest::SHA256.file('public/img/icon.png').hexdigest}"
    get '/subscribe.html'
    expect(last_response.body).to include("image: #{icon_path.to_json}")

    get '/update_cc.html'
    expect(Capybara.string(last_response.body).find('script[data-image]', visible: :all)['data-image']).to eq icon_path
  end

  it 'revalidates static assets using their content ETag' do
    get '/js/sup.js'
    etag = last_response.headers['ETag']
    expect(etag).to eq %("#{Digest::SHA256.file('public/js/sup.js').hexdigest}")

    get '/js/sup.js', {}, 'HTTP_IF_NONE_MATCH' => etag
    expect(last_response.status).to eq 304
    expect(last_response.body).to be_empty
  end

  it 'returns the asset for an old ETag even when its timestamp matches' do
    get '/js/sup.js', {}, 'HTTP_IF_NONE_MATCH' => '"old-content"',
                          'HTTP_IF_MODIFIED_SINCE' => File.mtime('public/js/sup.js').httpdate

    expect(last_response.status).to eq 200
    expect(last_response.body).to eq File.read('public/js/sup.js')
  end
end
