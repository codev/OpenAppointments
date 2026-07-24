# Channel registry for the messages system. A channel is a module with
# key/label/enabled?/incoming?/supports_long_text?/address_for/deliver.
module Messaging
  module_function

  def channels
    [ Messaging::EmailChannel, Messaging::Twilio, Messaging::Plivo, Messaging::Textanywhere ]
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

  def email_subject_template
    Setting.get("messages_email_subject").presence ||
      Messaging::Defaults::SETTINGS["messages_email_subject"]
  end
end
