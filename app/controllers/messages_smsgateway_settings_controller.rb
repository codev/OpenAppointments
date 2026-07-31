class MessagesSmsgatewaySettingsController < ApplicationController
  include MessagesProviderSettingsPage

  CHANNEL_KEY = "smsgateway".freeze
  SETTING_NAMES = %w[
    messages_smsgateway_enabled messages_smsgateway_incoming
    messages_smsgateway_url messages_smsgateway_login messages_smsgateway_password
    messages_smsgateway_signing_key
  ].freeze

  # POST /messages_smsgateway_settings/register_webhook - registers the inbound
  # webhook URL on the private server via its API.
  def register_webhook
    require_system_settings_edit!
    raise ArgumentError, "Configure and save the server settings first." unless Messaging::SmsGateway.enabled?

    Messaging::SmsGateway.register_webhook(send(:inbound_url))
    render json: { success: true }
  rescue ArgumentError, StandardError => e
    json_exception(ArgumentError.new(e.message))
  end
end
