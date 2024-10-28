class Stats
  include ActiveModel::Model
  include SlackSup::Models::Mixins::Pluralize

  attr_accessor :teams_count, :teams_active_count, :channels_count, :channels_enabled_count, :rounds_count, :sups_count, :users_in_sups_count, :users_opted_in_count, :users_count, :pairs, :outcomes

  # https://stackoverflow.com/questions/37456062/how-to-get-combinations-of-items-in-an-array-field-in-mongodb

  PAIRS_PIPELINE = [
    { '$unwind': '$user_ids' },
    { '$lookup': { from: 'sups', localField: '_id', foreignField: '_id', as: 'users' } },
    { '$unwind': '$users' },
    { '$unwind': '$users.user_ids' },
    { '$redact': { '$cond': { if: { '$cmp': ['$user_ids', '$users.user_ids'] }, then: '$$DESCEND', else: '$$PRUNE' } } },
    { '$group': { _id: { k1: '$user_ids', k2: '$users.user_ids' }, users: { '$sum': 0.5 } } },
    { '$sort': { _id: 1 } },
    { '$project':
      { _id: 1, users: 1,
        a: { '$cond': { if: { '$eq': [{ '$cmp': ['$_id.k1', '$_id.k2'] }, 1] }, then: '$_id.k2', else: '$_id.k1' } },
        b: { '$cond': { if: { '$eq': [{ '$cmp': ['$_id.k1', '$_id.k2'] }, -1] }, then: '$_id.k2', else: '$_id.k1' } } } },
    { '$group': { _id: { k1: '$a', k2: '$b' }, users: { '$sum': '$users' } } },
    { '$project': { _id: 0, user1: '$_id.k1', user2: '$_id.k2', count: { '$convert': { input: '$users', to: 'int' } } } }
  ]

  PAIRS_TO_USERNAMES_PIPELINE = [
    { '$lookup': { from: 'users', localField: 'user1', foreignField: '_id', as: 'user1' } },
    { '$lookup': { from: 'users', localField: 'user2', foreignField: '_id', as: 'user2' } },
    { '$project': { user1: { '$arrayElemAt': ['$user1', 0] }, user2: { '$arrayElemAt': ['$user2', 0] }, count: '$count' } },
    { '$project': { user1: '$user1.user_name', user2: '$user2.user_name', count: '$count' } },
    { '$sort': { count: -1 } }
  ]

  OUTCOMES_PIPELINE = [
    { '$group' => { _id: { outcome: '$outcome' }, count: { '$sum' => 1 } } }
  ]

  def initialize
    @teams_count = Team.count
    @teams_active_count = Team.active.count
    @channels_count = Channel.count
    @channels_enabled_count = Channel.enabled.count
    @rounds_count = Round.count
    @sups_count = Sup.count
    @users_in_sups_count = Sup.distinct(:user_ids).count
    @users_opted_in_count = User.opted_in.count
    @users_count = User.count
    @outcomes = Hash[
      Sup.collection.aggregate(OUTCOMES_PIPELINE).map do |row|
        [(row['_id']['outcome'] || 'unknown').to_sym, row['count']]
      end
    ]
    @pairs = Sup.collection.aggregate(PAIRS_PIPELINE)
  end

  def positive_outcomes_count
    ((outcomes[:all] || 0) + (outcomes[:some] || 0))
  end

  def reported_outcomes_count
    outcomes.values.sum - (outcomes[:unknown] || 0)
  end

  def unique_pairs_count
    pairs.count
  end

  def to_s
    messages = []
    messages << "S'Up connects #{pluralize(teams_active_count, 'team')} in #{pluralize(channels_enabled_count, 'channel')} with #{users_opted_in_count_percent}% (#{users_opted_in_count}/#{users_count}) of users opted in."
    if sups_count > 0
      messages << "Facilitated #{pluralize(sups_count, 'S\'Up')} " \
                  "in #{pluralize(rounds_count, 'round')} " \
                  "for #{pluralize(users_in_sups_count, 'user')} " \
                  "creating #{pluralize(unique_pairs_count, 'unique connections')} " \
                  "with #{positive_outcomes_count * 100 / sups_count}% positive outcomes " \
                  "from #{reported_outcomes_count * 100 / sups_count}% outcomes reported."
    end
    messages.join("\n")
  end

  private

  def users_opted_in_count_percent
    return 0 unless users_count && users_count > 0

    users_opted_in_count * 100 / users_count
  end
end
