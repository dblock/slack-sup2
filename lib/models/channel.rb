class Channel
  include Mongoid::Document
  include Mongoid::Timestamps
  include SlackSup::Models::Mixins::Pluralize
  include SlackSup::Models::Mixins::ShortLivedToken
  include SlackSup::Models::Mixins::Export

  field :channel_id, type: String
  field :inviter_id, type: String
  field :enabled, type: Boolean, default: true
  field :opt_in, type: Boolean, default: true

  scope :api, -> { where(api: true) }

  # enable API for this channel
  field :api, type: Boolean, default: false
  field :api_token, type: String
  field :token, type: String, default: -> { SecureRandom.hex }

  # sup size
  field :sup_size, type: Integer, default: 3
  # sup remaining odd users
  field :sup_odd, type: Boolean, default: true
  # sup frequency in weeks
  field :sup_time_of_day, type: Integer, default: 9 * 60 * 60
  field :sup_every_n_weeks, type: Integer, default: 1
  field :sup_recency, type: Integer, default: 12
  # sup day of the week
  field :sup_wday, type: Integer, default: -1
  # sup day of the week we ask for sup results
  field :sup_followup_wday, type: Integer, default: -1
  field :sup_tz, type: String, default: 'Eastern Time (US & Canada)'
  validates_presence_of :sup_tz

  field :sup_message, type: String

  # notify channel or admin
  field :sup_notify, type: String, default: 'channel'

  # auto-close old group DM conversations
  field :sup_close, type: Boolean, default: true

  # sup on the nth weekday of every month (1=1st, 2=2nd, 3=3rd, 4=4th, 5=last), nil=weekly
  field :sup_week_of_month, type: Integer

  WEEK_OF_MONTH_ORDINALS = {
    '1' => 1, '1st' => 1, 'first' => 1,
    '2' => 2, '2nd' => 2, 'second' => 2,
    '3' => 3, '3rd' => 3, 'third' => 3,
    '4' => 4, '4th' => 4, 'fourth' => 4,
    '5' => 5, '5th' => 5, 'fifth' => 5, 'last' => 5
  }.freeze

  # sync
  field :sync, type: Boolean, default: false
  field :last_sync_at, type: DateTime

  # custom team field
  field :team_field_label, type: String
  field :team_field_label_id, type: String

  has_many :users
  has_many :rounds, dependent: :destroy
  has_many :sups, dependent: :destroy
  has_many :exports, dependent: :destroy

  before_validation :validate_team_field_label
  before_validation :validate_team_field_label_id
  before_validation :validate_sup_time_of_day
  before_validation :validate_sup_every_n_weeks
  before_validation :validate_sup_week_of_month
  before_validation :validate_sup_size
  before_validation :validate_sup_recency
  before_create :set_sup_wday_to_tomorrow

  belongs_to :team

  index({ channel_id: 1, team_id: 1 }, unique: true)

  index({ enabled: 1 })
  scope :enabled, -> { where(enabled: true) }

  def api_url
    return unless api?

    "#{SlackRubyBotServer::Service.api_url}/channels/#{id}"
  end

  def api_s
    api? ? 'on' : 'off'
  end

  def opt_in_s
    opt_in? ? 'in' : 'out'
  end

  def opt_in_s
    opt_in? ? 'in' : 'out'
  end

  def slack_mention
    "<##{channel_id}>"
  end

  def slack_client
    team.slack_client
  end

  def info
    slack_client.conversations_info(channel: channel_id)
  end

  def find_user_by_slack_mention!(user_name)
    user_match = user_name.match(/^<@(.*)>$/)
    user = if user_match
             find_or_create_user!(user_match[1])
           else
             users.where({ user_name: ::Regexp.new("^#{Regexp.escape(user_name)}$", 'i') }).first
           end

    raise SlackSup::Error, "I don't know who #{user_name} is!" unless user

    user
  end

  def channel_admins
    users
      .in(channel_id: id, enabled: true, user_id: [inviter_id, team.activated_user_id].uniq.compact)
      .or(channel_id: id, enabled: true, is_admin: true)
      .or(channel_id: id, enabled: true, is_owner: true)
  end

  def channel_admins_slack_mentions
    (["<@#{inviter_id}>"] + channel_admins.map(&:slack_mention)).uniq
  end

  def self.parse_slack_mention(mention)
    channel_match = mention.match(/^<#(?<id>.*)\|(?<name>.*)>$/)
    channel_match ||= mention.match(/^<#(?<id>.*)>$/)
    channel_match['id'] if channel_match
  end

  def self.parse_slack_mention!(mention)
    parse_slack_mention(mention) || raise(SlackSup::Error, "Invalid channel mention #{mention}.")
  end

  def find_or_create_user!(user_id)
    user = users.where(user_id:).first
    user || users.create!(user_id:, sync: true, opted_in: opt_in)
  end

  def sync!
    tt = Time.now.utc
    updated_user_ids = []
    slack_client.conversations_members(channel: channel_id) do |page|
      page.members.each do |user_id|
        user_info = slack_client.users_info(user: user_id).user
        existing_user = users.where(user_id:).first
        if User.suppable_user?(user_info)
          if existing_user
            existing_user.enabled = true
            existing_user.update_info_attributes!(user_info)
            logger.info "Team #{team}: #{existing_user} updated in #{channel_id}."
            updated_user_ids << existing_user.id
          else
            new_user = users.new(user_id:, opted_in: opt_in)
            new_user.update_info_attributes!(user_info)
            logger.info "Team #{team}: #{new_user} added to #{channel_id}."
            updated_user_ids << new_user.id
          end
        elsif existing_user
          existing_user.enabled = false
          existing_user.update_info_attributes!(user_info)
          logger.info "Team #{team}: #{existing_user} disabled in #{channel_id}."
          updated_user_ids << existing_user.id
        else
          logger.info "Team #{team}: #{user_info.user_name}, #{user_info.user_id} skipped in #{channel_id}."
        end
      end
    end
    users.where(:_id.nin => updated_user_ids).each do |existing_user|
      logger.info "Team #{team}: #{existing_user} disabled in #{channel_id}."
      existing_user.update_attributes!(enabled: false)
    end
    update_attributes!(sync: false, last_sync_at: tt)
  end

  def stats
    @stats ||= ChannelStats.new(self)
  end

  def stats_s
    stats.to_s
  end

  def to_s
    "#{team}, channel_id=#{channel_id}"
  end

  def sup!
    sync!
    rounds.create!
  end

  def ask!
    round = last_round
    return unless round&.ask?

    round.ask!
    round
  end

  def ask_again!
    round = last_round
    return unless round&.ask_again?

    round.ask_again!
    round
  end

  def remind!
    round = last_round
    return unless round&.remind?

    round.remind!
    round
  end

  def close_old_sups!(limit: nil)
    closeable_old_sups(limit:).count(&:close!)
  end

  def closeable_old_sups(limit: nil)
    return [] unless sup_close

    latest_ran_at = rounds.where(:ran_at.ne => nil).max(:ran_at)
    return [] unless latest_ran_at

    old_round_ids = rounds.where(:ran_at.lt => latest_ran_at).distinct(:_id)
    return [] if old_round_ids.empty?

    old_sups = sups.where(:round_id.in => old_round_ids, :conversation_id.ne => nil, :closed_at => nil)
    old_sups = old_sups.limit(limit) if limit
    old_sups.to_a
  end

  def last_round
    rounds.desc(:created_at).first
  end

  def last_round_at
    round = last_round
    round ? round.created_at : nil
  end

  def sup_time_of_day_s
    Time.at(sup_time_of_day).utc.strftime('%l:%M %p').strip
  end

  def sup_every_n_weeks_s
    sup_every_n_weeks == 1 ? 'week' : "#{sup_every_n_weeks} weeks"
  end

  def sup_week_of_month_s
    { 1 => '1st', 2 => '2nd', 3 => '3rd', 4 => '4th', 5 => 'last' }[sup_week_of_month]
  end

  def sup_schedule_s
    if sup_week_of_month
      "on the #{sup_week_of_month_s} #{sup_day} of every month after #{sup_time_of_day_s}"
    else
      "on #{sup_day} after #{sup_time_of_day_s} every #{sup_every_n_weeks_s}"
    end
  end

  def sup_recency_s
    sup_recency == 1 ? 'week' : "#{sup_recency} weeks"
  end

  def sup_day
    Date::DAYNAMES[sup_wday]
  end

  def sup_followup_day
    Date::DAYNAMES[sup_followup_wday]
  end

  def sup_tzone
    ActiveSupport::TimeZone.new(sup_tz)
  end

  def sup_tzone_s
    now.strftime('%Z')
  end

  def now
    Time.now.utc.in_time_zone(sup_tzone)
  end

  def tomorrow
    now.tomorrow
  end

  # is it time to sup?
  def sup?
    return false unless team.active?

    # only sup on a certain day of the week
    now_in_tz = now
    return false unless now_in_tz.wday == sup_wday

    # sup after sup_time_of_day, 9am by default
    return false if now_in_tz < now_in_tz.beginning_of_day + sup_time_of_day

    if sup_week_of_month
      # monthly mode: must be the nth weekday of this month and not yet run this month
      return false unless now_in_tz.to_date == monthly_sup_date(now_in_tz.year, now_in_tz.month)

      last_round_at.nil? || last_round_at < now_in_tz.beginning_of_month
    else
      # don't sup more than sup_every_n_weeks, once a week by default
      time_limit = now_in_tz.end_of_day - sup_every_n_weeks.weeks
      (last_round_at || time_limit) <= time_limit
    end
  end

  def next_sup_at
    sup_week_of_month ? next_sup_at_monthly : next_sup_at_weekly
  end

  def next_sup_at_monthly
    now_in_tz = now
    year = now_in_tz.year
    month = now_in_tz.month
    loop do
      target = monthly_sup_date(year, month)
      start_of_month = Date.new(year, month, 1).in_time_zone(sup_tzone)
      ran_this_month = last_round_at && last_round_at >= start_of_month
      return target.in_time_zone(sup_tzone).beginning_of_day + sup_time_of_day if !ran_this_month && (target >= now_in_tz.to_date)

      month += 1
      if month > 12
        month = 1
        year += 1
      end
    end
  end

  def next_sup_at_weekly
    now_in_tz = now
    loop do
      time_limit = now_in_tz.end_of_day - sup_every_n_weeks.weeks

      return now_in_tz.beginning_of_day + sup_time_of_day if (now_in_tz.wday == sup_wday) &&
                                                             ((last_round_at || time_limit) <= time_limit)

      now_in_tz = now_in_tz.beginning_of_day + 1.day
    end
  end

  def next_sup_at_text
    [
      "Next round in #{slack_mention} is",
      Time.now > next_sup_at ? 'overdue' : nil,
      next_sup_at.strftime('%A, %B %e, %Y at %l:%M %p %Z').gsub('  ', ' '),
      '(' + next_sup_at.to_time.ago_or_future_in_words(highest_measure_only: true) + ').'
    ].compact.join(' ')
  end

  def last_sync_at_text
    tt = last_sync_at || last_round_at
    messages = []
    if tt
      updated_users_count = users.where(:updated_at.gte => last_sync_at).count
      messages << "Last users sync was #{tt.to_time.ago_in_words}, #{pluralize(updated_users_count, 'user')} updated."
    end
    if sync
      messages << 'Users will sync in the next hour.'
    else
      messages << 'Users will sync before the next round.'
      messages << next_sup_at_text
    end
    messages.compact.join(' ')
  end

  def sup_notify_s
    case sup_notify
    when 'off' then 'off'
    when 'admin' then 'admin'
    else 'channel'
    end
  end

  def inform!(message)
    slack_client.chat_postMessage(text: message, channel: channel_id, as_user: true)
  end

  def inform_notify!(message)
    return if sup_notify == 'off'

    if sup_notify == 'admin'
      team.inform!(message)
    else
      inform!(message)
    end
  end

  def export_filename(root)
    super(root, channel_id)
  end

  def export_zip!(root, options = {})
    super(root, channel_id, options)
  end

  def export!(root, options = {})
    super
    stats.export!(root, options)
    super(root, options.merge(name: 'users', presenter: Api::Presenters::UserPresenter, coll: users))
    target_rounds = options[:max_rounds_count] ? rounds.desc(:ran_at).limit(options[:max_rounds_count]) : rounds
    target_sups = options[:max_rounds_count] ? sups.where(:round_id.in => target_rounds.distinct(:_id)) : sups
    super(root, options.merge(name: 'rounds', presenter: Api::Presenters::RoundPresenter, coll: target_rounds))
    super(root, options.merge(name: 'sups', presenter: Api::Presenters::SupPresenter, coll: target_sups))
    target_rounds.each do |round|
      round.export!(
        File.join(root, File.join('rounds', round.ran_at&.strftime('%F') || round.id)),
        options
      )
    end
  end

  def is_admin?(user_or_user_id)
    user_id = user_or_user_id.is_a?(User) ? user_or_user_id.user_id : user_or_user_id
    return true if user_id == inviter_id

    user = user_or_user_id.is_a?(User) ? user_or_user_id : users.where(user_id: user_or_user_id).first
    return true if user&.channel_admin?

    team.is_admin?(user_id)
  end

  def bot_in_channel?
    slack_client.conversations_members(channel: channel_id) do |response|
      return true if response.members.include?(team.bot_user_id)
    end
    false
  end

  def leave!
    update_attributes!(enabled: false, sync: false)
  end

  private

  def validate_team_field_label
    return unless team_field_label && (team_field_label_changed? || saved_change_to_team_field_label?)

    profile_fields = team.slack_client_with_activated_user_access.team_profile_get.profile.fields
    label = profile_fields.detect { |field| field.label.casecmp(team_field_label.downcase).zero? }
    if label
      self.team_field_label_id = label.id
      self.team_field_label = label.label
    else
      errors.add(:team_field_label, "Custom profile team field _#{team_field_label}_ is invalid. Possible values are _#{profile_fields.map(&:label).join('_, _')}_.")
    end
  end

  def validate_team_field_label_id
    self.team_field_label_id = nil unless team_field_label
  end

  def validate_sup_time_of_day
    return if sup_time_of_day && sup_time_of_day >= 0 && sup_time_of_day < 24 * 60 * 60

    errors.add(:sup_time_of_day, "S'Up time of day _#{sup_time_of_day}_ is invalid.")
  end

  def validate_sup_week_of_month
    return if sup_week_of_month.nil? || (1..5).include?(sup_week_of_month)

    errors.add(:sup_week_of_month, "S'Up week of month _#{sup_week_of_month}_ is invalid, must be between 1 and 5.")
  end

  def validate_sup_every_n_weeks
    return if sup_every_n_weeks >= 1

    errors.add(:sup_every_n_weeks, "S'Up every _#{sup_every_n_weeks}_ is invalid, must be at least 1.")
  end

  def validate_sup_recency
    return if sup_recency >= 1

    errors.add(:sup_recency, "Don't S'Up with the same people more than every _#{sup_recency_s}_ is invalid, must be at least 1.")
  end

  def validate_sup_size
    return if sup_size >= 2

    errors.add(:sup_size, "S'Up for _#{sup_size}_ is invalid, requires at least 2 people to meet.")
  end

  def monthly_sup_date(year, month)
    if sup_week_of_month == 5 # last
      last = Date.new(year, month, -1)
      last - ((last.wday - sup_wday) % 7)
    else
      first = Date.new(year, month, 1)
      first_occurrence = first + ((sup_wday - first.wday) % 7)
      first_occurrence + ((sup_week_of_month - 1) * 7)
    end
  end

  def set_sup_wday_to_tomorrow
    if sup_wday == -1
      tomorrow_wday = tomorrow.wday
      self.sup_wday = case tomorrow_wday
                      when Date::SATURDAY, Date::SUNDAY
                        Date::MONDAY
                      else
                        tomorrow_wday
                      end
    end
    if sup_followup_wday == -1
      self.sup_followup_wday = case sup_wday
                               when Date::WEDNESDAY
                                 Date::FRIDAY
                               when Date::THURSDAY, Date::FRIDAY
                                 Date::TUESDAY
                               else
                                 Date::THURSDAY
                               end
    end
  end
end
