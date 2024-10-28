class TeamStats
  include ActiveModel::Model
  include SlackSup::Models::Mixins::Pluralize
  include SlackSup::Models::Mixins::Export

  attr_accessor :channels_count, :channels_enabled_count, :rounds_count, :sups_count, :users_in_sups_count, :users_opted_in_count, :users_count, :pairs, :outcomes, :team

  def initialize(team)
    @team = team
    @channels_count = team.channels.count
    @channels_enabled_count = team.channels.enabled.count
    channel_ids = team.channels.enabled.distinct(:_id)
    @rounds_count = Round.where(:channel_id.in => channel_ids).count
    @sups_count = Sup.where(:channel_id.in => channel_ids).count
    @users_in_sups_count = User.where(:_id.in => Sup.where(:channel_id.in => channel_ids).distinct(:user_ids)).distinct(:user_id).count
    @users_opted_in_count = User.where(:channel_id.in => channel_ids, opted_in: true).distinct(:user_id).count
    @users_count = User.where(:channel_id.in => channel_ids).distinct(:user_id).count
    @outcomes = Hash[
      Sup.collection.aggregate(
        [
          { '$match' => { channel_id: { '$in' => channel_ids } } },
          { '$group' => { _id: { outcome: '$outcome' }, count: { '$sum' => 1 } } }
        ]
      ).map do |row|
        [(row['_id']['outcome'] || 'unknown').to_sym, row['count']]
      end
    ]

    # https://stackoverflow.com/questions/37456062/how-to-get-combinations-of-items-in-an-array-field-in-mongodb

    pairs_pipeline = [
      { '$match': { channel_id: { '$in' => team.channels.distinct(:_id) } } },
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

    @pairs = Sup.collection.aggregate(pairs_pipeline)
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
    messages << if users_opted_in_count == 0 && channels_enabled_count == 0
                  "Team S'Up is not in any channels. Invite S'Up to a channel with some users to get started!"
                elsif users_opted_in_count == 0
                  "Team S'Up is in #{pluralize(channels_enabled_count, 'channel')} (#{team.channels.enabled.map(&:slack_mention).and}), but does not have any users opted in. Invite some users to S'Up channels to get started!"
                else
                  "Team S'Up connects #{pluralize(users_opted_in_count, 'user')} in #{pluralize(channels_enabled_count, 'channel')} (#{team.channels.enabled.map(&:slack_mention).and})."
                end
    messages << "Team S'Up has #{users_opted_in_count_percent}% (#{users_opted_in_count}/#{users_count}) of users opted in." if users_count > 0 && users_opted_in_count > 0
    if sups_count > 0
      messages << "Facilitated #{pluralize(sups_count, 'S\'Up')} " \
                  "in #{pluralize(rounds_count, 'round')} " \
                  "for #{pluralize(users_count, 'user')} " \
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
