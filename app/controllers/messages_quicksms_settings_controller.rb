class MessagesQuicksmsSettingsController < ApplicationController
  include MessagesProviderSettingsPage

  CHANNEL_KEY = "quicksms".freeze
  SETTING_NAMES = %w[
    messages_quicksms_enabled messages_quicksms_incoming messages_quicksms_default_country_only
    messages_quicksms_api_key messages_quicksms_from messages_quicksms_signing_secret
  ].freeze
end
