class MessagesTextanywhereSettingsController < ApplicationController
  include MessagesProviderSettingsPage

  CHANNEL_KEY = "textanywhere".freeze
  SETTING_NAMES = %w[
    messages_textanywhere_enabled messages_textanywhere_incoming
    messages_textanywhere_api_key messages_textanywhere_from
  ].freeze
end
