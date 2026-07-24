class MessagesEmailSettingsController < ApplicationController
  include MessagesProviderSettingsPage

  CHANNEL_KEY = "email".freeze
  SETTING_NAMES = %w[
    messages_email_enabled messages_email_incoming messages_email_mode
    messages_email_smtp_host messages_email_smtp_port messages_email_smtp_username
    messages_email_smtp_password messages_email_smtp_tls
    messages_email_incoming_mode messages_email_imap_host messages_email_imap_port
    messages_email_imap_username messages_email_imap_password
  ].freeze
end
