class ChannelStatsPair
  include Mongoid::Document

  field :user1, type: String
  field :user2, type: String
  field :count, type: Integer
end
