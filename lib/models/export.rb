class Export
  include Mongoid::Document
  include Mongoid::Timestamps
  include SlackSup::Models::Mixins::ShortLivedToken

  belongs_to :team
  belongs_to :channel, optional: true

  field :user_id, type: String

  validates_presence_of :team, :user_id

  field :max_rounds_count, type: Integer

  field :filename, type: String
  field :exported, type: Boolean, default: false

  scope :requested, -> { where(exported: false) }

  def to_s
    "id=#{id}, #{channel || team}, user_id=#{user_id}, exported=#{exported}"
  end

  def token
    target.token
  end

  def target
    channel || team
  end

  def target_s
    channel ? "#{channel.slack_mention} channel" : 'team'
  end

  def export!
    return if exported?

    Api::Middleware.logger.info "Exporting data for #{self}."
    path = File.join(Dir.tmpdir, 'slack-sup2', _id)
    FileUtils.rm_rf(path)
    FileUtils.makedirs(path)
    options = {}
    options[:max_rounds_count] = max_rounds_count if max_rounds_count
    filename = target.export_zip!(path, options)
    update_attributes!(filename: filename, exported: true)
    Api::Middleware.logger.info "Exported data for #{self}, filename=#{filename}."
    notify!
    filename
  end

  def notify!
    team.slack_client.chat_postMessage(
      channel: team.slack_client.conversations_open(users: user_id).channel.id,
      text: "Click here to download your #{target_s} data.",
      attachments: [
        {
          text: '',
          attachment_type: 'default',
          actions: [
            {
              type: 'button',
              text: 'Download',
              url: "#{SlackRubyBotServer::Service.url}/api/data/#{_id}?access_token=#{CGI.escape(short_lived_token)}"
            }
          ]
        }
      ]
    )
  end
end
