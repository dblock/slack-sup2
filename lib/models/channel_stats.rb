class ChannelStats
  include ActiveModel::Model
  include SlackSup::Models::Mixins::Pluralize
  include SlackSup::Models::Mixins::Export

  attr_accessor :rounds_count, :sups_count, :users_in_sups_count, :users_opted_in_count, :users_count, :outcomes, :pairs, :pairs_of_user_names, :channel

  def initialize(channel)
    @channel = channel
    @rounds_count = channel.rounds.count
    @sups_count = channel.sups.count
    @users_in_sups_count = channel.sups.distinct(:user_ids).count
    @users_opted_in_count = channel.users.opted_in.count
    @users_count = channel.users.count
    @outcomes = Hash[
      Sup.collection.aggregate(
        [
          { '$match' => { channel_id: channel.id } }
        ] + Stats::OUTCOMES_PIPELINE
      ).map do |row|
        [(row['_id']['outcome'] || 'unknown').to_sym, row['count']]
      end
    ]

    pairs_pipeline = [
      { '$match': { channel_id: channel.id } }
    ] + Stats::PAIRS_PIPELINE
    @pairs = Sup.collection.aggregate(pairs_pipeline)

    pairs_user_name_pipeline = pairs_pipeline + Stats::PAIRS_TO_USERNAMES_PIPELINE
    @pairs_of_user_names = Sup.collection.aggregate(pairs_user_name_pipeline).map { |doc| ChannelStatsPair.new(doc) }
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

  def export!(root, options = {})
    super(root, options.merge(name: 'stats', presenter: Api::Presenters::ChannelStatsPresenter))
    super(root, options.merge(name: 'pairs', presenter: Api::Presenters::ChannelStatsPairPresenter, coll: pairs_of_user_names))
  end

  def to_s
    messages = []
    messages << "Channel S'Up connects groups of #{channel.sup_size} people on #{channel.sup_day} after #{channel.sup_time_of_day_s} every #{channel.sup_every_n_weeks_s} in #{channel.slack_mention}."
    messages << if channel.sup_size > users_opted_in_count && users_opted_in_count > 0
                  "The channel S'Up currently only has #{pluralize(users_opted_in_count, 'user')} opted in. Invite some more users to S'Up!"
                elsif users_count > 0 && users_opted_in_count > 0
                  "This channel S'Up started #{channel.created_at.ago_in_words(highest_measure_only: true)} and has #{users_opted_in_count_percent}% (#{users_opted_in_count}/#{users_count}) of users opted in."
                elsif users_count > 0
                  "None of #{pluralize(users_count, 'user')} opted into S'Up. Invite some more users to get started!"
                else
                  "There's only 1 user in this channel. Invite some more users to this channel to get started!"
                end
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
