# Channel registry for the messages system. A channel is a module with
# key/label/enabled?/incoming?/supports_long_text?/address_for/deliver.
module Messaging
  module_function

  def channels
    [ Messaging::EmailChannel, Messaging::SmsGateway, Messaging::Twilio, Messaging::Plivo, Messaging::Textanywhere ]
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

  # Global switch on Messages > Settings. Gates automatic notifications only;
  # password resets and manual sends are unaffected.
  def enabled?
    Setting.get("messages_enabled", "1") == "1"
  end

  # Per-provider "send only to default country phones" switch. Returns an error
  # string when the address falls outside the default country, else nil.
  def country_restriction_error(channel_key, address)
    return nil unless Setting.get("messages_#{channel_key}_default_country_only", "0") == "1"

    code = Messaging::Template.default_country_code
    return nil if address.to_s.start_with?(code)

    "recipient #{address} is outside the default country (#{code})"
  end

  def email_subject_template
    Setting.get("messages_email_subject").presence ||
      Messaging::Defaults::SETTINGS["messages_email_subject"]
  end
end
