module Api
  module Presenters
    module SupPresenter
      include Roar::JSON::HAL
      include Roar::Hypermedia
      include Grape::Roar::Representer
      include BasePresenter

      property :id, type: String, desc: "S'Up ID."
      property :outcome, type: String, desc: "S'up outcome."
      property :created_at, type: DateTime, desc: "Date/time when the S'Up was created."
      property :updated_at, type: DateTime, desc: "Date/time when the S'Up was updated."
      property :captain_user_name, type: String, desc: 'Captain user name.'
      property :suggested_by_user_name, type: String, desc: 'Suggested-by user name.'
      property :suggested_text, type: String, desc: "Suggestion text for an on-demand S'Up."

      collection :users, extend: UserPresenter, as: :users, embedded: true

      link :captain do |opts|
        next unless captain_id

        "#{base_url(opts)}/api/users/#{captain_id}"
      end

      link :suggested_by do |opts|
        next unless suggested_by_id

        "#{base_url(opts)}/api/users/#{suggested_by_id}"
      end

      link :round do |opts|
        next unless round_id

        "#{base_url(opts)}/api/rounds/#{round_id}"
      end

      link :self do |opts|
        "#{base_url(opts)}/api/sups/#{id}"
      end
    end
  end
end
