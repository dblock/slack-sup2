module Api
  module Presenters
    module SupPresenter
      include Roar::JSON::HAL
      include Roar::Hypermedia
      include Grape::Roar::Representer

      property :id, type: String, desc: "S'Up ID."
      property :outcome, type: String, desc: "S'up outcome."
      property :created_at, type: DateTime, desc: "Date/time when the S'Up was created."
      property :updated_at, type: DateTime, desc: "Date/time when the S'Up was updated."
      property :captain_user_name, type: String, desc: 'Captain user name.'

      collection :users, extend: UserPresenter, as: :users, embedded: true

      link :captain do |opts|
        next unless captain_id
        next unless opts.key?(:env)

        request = Grape::Request.new(opts[:env])
        "#{request.base_url}/api/users/#{captain_id}"
      end

      link :round do |opts|
        next unless opts.key?(:env)

        request = Grape::Request.new(opts[:env])
        "#{request.base_url}/api/rounds/#{round_id}"
      end

      link :self do |opts|
        next unless opts.key?(:env)

        request = Grape::Request.new(opts[:env])
        "#{request.base_url}/api/sups/#{id}"
      end
    end
  end
end
