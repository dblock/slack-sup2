# a Sup round
class Round
  include Mongoid::Document
  include Mongoid::Timestamps
  include SlackSup::Models::Mixins::Export

  TIMEOUT = 60

  field :ran_at, type: DateTime
  field :asked_at, type: DateTime
  field :asked_again_at, type: DateTime
  field :reminded_at, type: DateTime

  belongs_to :channel
  validates_presence_of :channel
  has_many :sups, dependent: :destroy

  field :total_users_count
  field :opted_in_users_count
  field :opted_out_users_count
  field :paired_users_count
  field :missed_users_count

  after_create :run!

  def to_s
    "id=#{id}, #{channel}"
  end

  def ask_again?
    return false unless asked_at
    return false if asked_again_at
    # do not ask within 48 hours since asked_at
    return false if Time.now.utc < (asked_at + 48.hours)

    true
  end

  def ask_again!
    return if asked_again_at

    update_attributes!(asked_again_at: Time.now.utc)
    sups.where(outcome: 'later').each(&:ask_again!)
  end

  def ask?
    return false if asked_at

    # do not ask within 24 hours
    return false if Time.now.utc < (ran_at + 24.hours)

    # only ask on sup_followup_day
    now_in_tz = Time.now.utc.in_time_zone(channel.sup_tzone)
    return false unless now_in_tz.wday == channel.sup_followup_wday

    # do not bother people before S'Up time
    return false if now_in_tz < now_in_tz.beginning_of_day + channel.sup_time_of_day

    true
  end

  def ask!
    return if asked_at

    update_attributes!(asked_at: Time.now.utc)
    sups.each(&:ask!)
  end

  def remind?
    # don't remind if already tried to record outcome
    return false if asked_at || reminded_at

    # do not remind before 24 hours
    return false unless Time.now.utc > (ran_at + 24.hours)

    # do not bother people before S'Up time
    now_in_tz = Time.now.utc.in_time_zone(channel.sup_tzone)
    return false if now_in_tz < now_in_tz.beginning_of_day + channel.sup_time_of_day

    true
  end

  def remind!
    return if reminded_at

    update_attributes!(reminded_at: Time.now.utc)
    sups.each(&:remind!)
  end

  def stats
    @stats ||= RoundStats.new(self)
  end

  def export!(root)
    super
    super(root, 'sups', Api::Presenters::SupPresenter, sups)
  end

  def paired_users
    User.find(sups.distinct(:user_ids))
  end

  def missed_users
    channel.users - paired_users
  end

  private

  def run!
    group!
    dm!
    notify!
  end

  def group!
    return if ran_at

    update_attributes!(ran_at: Time.now.utc)
    logger.info "Generating sups for #{channel} of #{channel.users.suppable.count} users."
    all_users = channel.users.suppable.to_a.shuffle
    begin
      solve(all_users)
      Ambit.fail!
    rescue Ambit::ChoicesExhausted
      solve_remaining(all_users - sups.map(&:users).flatten) if channel.sup_odd?
      paired_count = sups.distinct(:user_ids).count
      update_attributes!(
        total_users_count: channel.users.enabled.count,
        opted_in_users_count: channel.users.opted_in.count,
        opted_out_users_count: channel.users.opted_out.count,
        paired_users_count: paired_count,
        missed_users_count: all_users.count - paired_count
      )
      logger.info "Finished round for #{channel}, users=#{total_users_count}, opted out=#{opted_out_users_count}, paired=#{paired_users_count}, missed=#{missed_users_count}."
    end
  end

  def dm!
    sups.each do |sup|
      sup.sup!
    rescue StandardError => e
      logger.warn "Error DMing sup #{self} #{sup} #{e.message}."
    end
  end

  def notify!
    message = if total_users_count == 0
                "Hi! Unfortunately, I couldn't find any users to pair in a new S'Up. Invite some more users to this channel!"
              elsif opted_in_users_count == 0
                "Hi! Unfortunately, I couldn't find any opted in users to pair in a new S'Up. Invite some more users to this channel!"
              elsif paired_users_count == 0 && channel.sup_size > opted_in_users_count
                "Hi! Unfortunately, I only found #{pluralize(opted_in_users_count, 'user')} to pair in a new S'Up of #{channel.sup_size}. Invite some more users to this channel, lower `@sup set size` or adjust `@sup set odd`."
              elsif paired_users_count == 0
                "Hi! Unfortunately I wasn't able to find groups for any of the #{pluralize(total_users_count, 'user')} in this channel. Consider increasing the value of `@sup set weeks`, or lowering the value of `@sup set recency`."
              elsif missed_users_count > 0
                "Hi! I have created a new round with #{pluralize(sups.count, 'S\'Up')}, pairing #{pluralize(paired_users_count, 'user')}. Unfortunately, I wasn't able to find a group for the remaining #{missed_users_count}. Consider increasing the value of `@sup set weeks`, lowering the value of `@sup set recency`, or adjusting `@sup set odd`."
              else
                "Hi! I have created a new round with #{pluralize(sups.count, 'S\'Up')}, pairing all of #{pluralize(paired_users_count, 'user')}."
              end
    channel.inform! message
    logger.info "Notified #{channel} about the new round. #{message}"
  rescue StandardError => e
    logger.warn "Error notifying #{channel} #{self} #{e.message}."
  end

  def solve(remaining_users)
    combination = group(remaining_users)
    Ambit.clear! if ran_at + Round::TIMEOUT.seconds < Time.now.utc
    Ambit.fail! if meeting_already?(combination)
    Ambit.fail! if same_team?(combination)
    Ambit.fail! if met_recently?(combination)
    Sup.create!(round: self, channel:, users: combination)
    logger.info "   Creating sup for #{combination.map(&:user_name)}, #{sups.count * channel.sup_size} out of #{channel.users.suppable.count}."
    Ambit.clear! if sups.count * channel.sup_size == channel.users.suppable.count
    solve(remaining_users - combination)
  end

  def solve_remaining(remaining_users)
    if remaining_users.count == 1
      # find a sup to add this user to
      sups.each do |sup|
        next if met_recently?(sup.users + remaining_users)

        logger.info "   Adding #{remaining_users.map(&:user_name).and} to #{sup.users.map(&:user_name)}."
        sup.users.concat(remaining_users)
        sup.save!
        return
      end
      logger.info "   Failed to pair #{remaining_users.map(&:user_name).and}."
    elsif remaining_users.count > 0 &&
          remaining_users.count < channel.sup_size &&
          !met_recently?(remaining_users)

      # pair remaining
      Sup.create!(round: self, channel:, users: remaining_users)
    end
  end

  def group(remaining_users, combination = [])
    if combination.size == channel.sup_size
      combination
    else
      user = Ambit.choose(remaining_users)
      Ambit.fail! if combination.include?(user)
      group(remaining_users - [user], combination + [user])
    end
  end

  def meeting_already?(users)
    users.any? do |user|
      sups.any? do |sup|
        sup.user_ids.include? user.id
      end
    end
  end

  def same_team?(users)
    pairs = users.to_a.permutation(2)
    pairs.any? do |pair|
      pair.first.custom_team_name == pair.last.custom_team_name &&
        pair.first.custom_team_name &&
        pair.last.custom_team_name
    end
  end

  def met_recently?(users)
    pairs = users.to_a.permutation(2)
    pairs.any? do |pair|
      Sup.where(
        :round_id.ne => _id,
        :user_ids.in => pair.map(&:id),
        :created_at.gt => Time.now.utc - channel.sup_recency.weeks
      ).any? do |sup|
        pair.all? do |user|
          sup.user_ids.include?(user.id)
        end
      end
    end
  end
end
