# Shared behavior of the per-provider messages settings pages: admin-gated,
# saves a whitelisted name list, and runs the Test setup actions on the form as
# posted (unsaved edits included, a blank secret standing for the stored one).
module MessagesProviderSettingsPage
  extend ActiveSupport::Concern

  included do
    include BackendPage
    include SettingsPage

    layout "backend"

    before_action :forbid_unless_system_settings_edit
  end

  def index
    backend_page_vars(page_title: helpers.lang("messages"), active_menu: "messages")
    html_vars(inbound_url: inbound_url)
    render :index
  end

  def save
    require_system_settings_edit!
    save_setting_rows(self.class.controller_path.to_sym, allowed_names: self.class::SETTING_NAMES + [ default_switch_name ]) do |name, value|
      next value unless name == default_switch_name

      apply_default_switch(value)
      nil
    end
  rescue ArgumentError => e
    settings_failed(e)
  end

  # POST .../test_credentials: {success, message} from the channel's check.
  def test_credentials
    require_system_settings_edit!
    ok, message = channel.check_credentials(posted_config)
    render json: { success: ok, message: message.presence || helpers.lang("messages_test_credentials_ok") }
  rescue ArgumentError => e
    render json: { success: false, message: e.message }
  end

  # POST .../test_send: one message to params[:address] through the posted
  # configuration, recorded in the Messages log like any other send.
  def test_send
    require_system_settings_edit!
    config = posted_config
    address = test_address(config)
    message = Message.create!(direction: "outgoing", channel: channel.key, status: "queued", to_address: address,
                              subject: "OpenAppointments test message", body: "OpenAppointments test message")
    begin
      channel.deliver(message, config)
      message.update!(status: "sent", error: nil)
      render json: { success: true, message: helpers.lang("messages_test_sent") }
    rescue StandardError => e
      message.update!(status: "failed", error: e.message.truncate(255))
      render json: { success: false, message: e.message }
    end
  rescue ArgumentError => e
    render json: { success: false, message: e.message }
  end

  private

  def channel = Messaging.channel(self.class::CHANNEL_KEY)

  # The form's values by name, stripped; blank secrets are already dropped.
  def posted_settings
    @posted_settings ||= setting_row_params(self.class.controller_path.to_sym)
                           .to_h { |row| [ row["name"], row["value"].to_s.strip ] }
                           .slice(*self.class::SETTING_NAMES)
  end

  def posted_config = Messaging.config(posted_settings)

  # The test recipient: an email address for the email channel, else a phone
  # number in E.164 that passes the posted country restriction.
  def test_address(config)
    raw = params[:address].to_s.strip
    if channel.key == "email"
      raise ArgumentError, helpers.lang("invalid_email") unless raw.match?(URI::MailTo::EMAIL_REGEXP)

      return raw
    end

    number = Messaging::Template.e164(raw)
    raise ArgumentError, helpers.lang("fields_are_required") if number.blank?

    restriction = Messaging.country_restriction_error(channel.key, number, config)
    raise ArgumentError, restriction if restriction

    number
  end

  # The page's Default switch posts as messages_<key>_default; it is not a
  # setting of its own but writes the one messages_default_channel row.
  def default_switch_name = "messages_#{self.class::CHANNEL_KEY}_default"

  # On makes this provider the default (any other loses it); off clears the
  # default only when it is this provider.
  def apply_default_switch(value)
    key = self.class::CHANNEL_KEY
    if value == "1"
      Setting.set("messages_default_channel", key)
    elsif Messaging.default_channel_key == key
      Setting.set("messages_default_channel", "")
    end
  end

  # Webhook URL to paste into the SMS provider console (nil for email).
  def inbound_url
    key = self.class::CHANNEL_KEY
    return nil if key == "email"

    "#{Messaging::Template.base_url}/messages/inbound/#{key}/#{Setting.get('messages_inbound_token')}"
  end
end
