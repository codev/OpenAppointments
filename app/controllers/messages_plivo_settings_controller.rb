class MessagesPlivoSettingsController < ApplicationController
  include MessagesProviderSettingsPage

  CHANNEL_KEY = "plivo".freeze
  SETTING_NAMES = %w[
    messages_plivo_enabled messages_plivo_incoming
    messages_plivo_auth_id messages_plivo_auth_token messages_plivo_from
  ].freeze
end
