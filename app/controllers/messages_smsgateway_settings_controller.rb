class MessagesSmsgatewaySettingsController < ApplicationController
  include MessagesProviderSettingsPage

  CHANNEL_KEY = "smsgateway".freeze
  SETTING_NAMES = %w[
    messages_smsgateway_enabled messages_smsgateway_incoming
    messages_smsgateway_url messages_smsgateway_login messages_smsgateway_password
    messages_smsgateway_signing_key messages_smsgateway_default_country_only
  ].freeze

  # POST /messages_smsgateway_settings/save. Activating (either switch) first
  # validates the credentials against the server; turning incoming on registers
  # the webhook exactly once (stale duplicates removed), turning it off
  # deregisters.
  def save
    require_system_settings_edit!
    merged = merged_settings
    active = merged["messages_smsgateway_enabled"] == "1" || merged["messages_smsgateway_incoming"] == "1"

    if active
      error = Messaging::SmsGateway.validate(
        url: merged["messages_smsgateway_url"], user: merged["messages_smsgateway_login"],
        pass: merged["messages_smsgateway_password"]
      )
      raise ArgumentError, "#{helpers.lang('messages_smsgateway_invalid')} #{error}" if error
    end

    merged.each { |name, value| Setting.set(name, value) }
    switch = default_switch_value
    apply_default_switch(switch) if switch

    if merged["messages_smsgateway_incoming"] == "1" && active
      begin
        Messaging::SmsGateway.ensure_webhook(inbound_url)
      rescue StandardError => e
        raise ArgumentError, "#{helpers.lang('messages_smsgateway_invalid')} #{e.message}"
      end
    else
      begin
        Messaging::SmsGateway.remove_webhooks if Messaging::SmsGateway.base_url.present? &&
                                                 Messaging::SmsGateway.login.present?
      rescue StandardError
        nil # Deactivating must not fail on an unreachable server.
      end
    end

    settings_saved
  rescue ArgumentError => e
    settings_failed(e)
  end

  private

  def default_switch_value
    setting_row_params(:messages_smsgateway_settings).find { |row| row["name"] == default_switch_name }&.dig("value")
  end

  # Posted values (a blank password keeps the stored one) over the stored ones.
  def merged_settings
    config = posted_config
    SETTING_NAMES.index_with { |name| config[name] }
  end
end
