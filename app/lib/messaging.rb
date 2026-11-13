# Channel registry for the messages system. A channel is a module with
# key/label/enabled?/incoming?/supports_long_text?/address_for/deliver.
module Messaging
  module_function

  def channels
    [ Messaging::EmailChannel, Messaging::SmsGateway, Messaging::Twilio, Messaging::Plivo, Messaging::Textanywhere,
      Messaging::Quicksms ]
  end

  def channel(key)
    channels.find { |c| c.key == key.to_s }
  end

  def enabled_channels
    channels.select(&:enabled?)
  end

  def enabled_channel_keys
    enabled_channels.map(&:key)
  end

  def incoming_channels
    channels.select { |c| c.enabled? && c.incoming? }
  end

  # The provider pre-selected when a message is sent from a customer's page:
  # the one whose Default switch is on, counted only while it is enabled.
  def default_channel_key = Setting.get("messages_default_channel").to_s

  def default_channel
    enabled_channels.find { |c| c.key == default_channel_key }
  end

  # A channel's configuration: any setting name answers from the stored settings
  # (with the code default), overlaid with posted values for the provider page
  # tests, which run on the form as it stands rather than on what was saved.
  def config(overrides = {})
    Hash.new { |_, name| Setting.get(name, Messaging::Defaults::SETTINGS[name]).to_s }.merge(overrides)
  end

  # Global choice on Messages > Settings: "1" on, "0" off, "debug" on with every
  # outgoing email and message redirected to the intercept addresses. Off gates
  # automatic notifications only; password resets and manual sends still go.
  def enabled?
    %w[1 debug].include?(Setting.get("messages_enabled", "1"))
  end

  def debug?
    Setting.get("messages_enabled", "1") == "debug"
  end

  # Debug destination for a channel: the intercept email for email, the phone
  # for every other channel.
  def intercept_address(channel_key)
    Setting.get(channel_key.to_s == "email" ? "messages_intercept_email" : "messages_intercept_phone").presence
  end

  # The real recipient noted on top of a redirected body.
  def mark_original_to(body, address)
    "ORIGINAL-TO: #{address}\n#{body}"
  end

  # Per-provider "send only to default country phones" switch. Returns an error
  # string when the address falls outside the default country, else nil.
  def country_restriction_error(channel_key, address, config = Messaging.config)
    return nil unless config["messages_#{channel_key}_default_country_only"] == "1"

    code = Messaging::Template.default_country_code
    return nil if address.to_s.start_with?(code)

    "recipient #{address} is outside the default country (#{code})"
  end

  def email_subject_template
    Setting.get("messages_email_subject").presence ||
      Messaging::Defaults::SETTINGS["messages_email_subject"]
  end
end
