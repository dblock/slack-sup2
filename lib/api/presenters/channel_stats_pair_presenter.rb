module Api
  module Presenters
    module ChannelStatsPairPresenter
      include Roar::JSON::HAL
      include Roar::Hypermedia
      include Grape::Roar::Representer
      include BasePresenter

      property :user1
      property :user2
      property :count
    end
  end
end
