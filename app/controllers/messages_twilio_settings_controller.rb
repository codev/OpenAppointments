class MessagesTwilioSettingsController < ApplicationController
  include MessagesProviderSettingsPage

  CHANNEL_KEY = "twilio".freeze
  SETTING_NAMES = %w[
    messages_twilio_enabled messages_twilio_incoming
    messages_twilio_account_sid messages_twilio_auth_token messages_twilio_from
  ].freeze
end
