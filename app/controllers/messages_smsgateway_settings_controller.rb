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
      return render json: { success: false, message: "#{helpers.lang('messages_smsgateway_invalid')} #{error}" } if error
    end

    setting_row_params(setting_rows_key).each do |row|
      next unless SETTING_NAMES.include?(row["name"])

      Setting.set(row["name"], row["value"].to_s.strip)
    end

    if merged["messages_smsgateway_incoming"] == "1" && active
      begin
        Messaging::SmsGateway.ensure_webhook(inbound_url)
      rescue StandardError => e
        return render json: { success: false,
                              message: "#{helpers.lang('messages_smsgateway_invalid')} #{e.message}" }
      end
    else
      begin
        Messaging::SmsGateway.remove_webhooks if Messaging::SmsGateway.base_url.present? &&
                                                 Messaging::SmsGateway.login.present?
      rescue StandardError
        nil # Deactivating must not fail on an unreachable server.
      end
    end

    render json: { success: true }
  rescue ArgumentError => e
    json_exception(e)
  end

  # POST /messages_smsgateway_settings/test_sms - validates the saved settings
  # and sends a real SMS through the gateway, recorded in the message logs.
  def test_sms
    require_system_settings_edit!
    raise ArgumentError, "Save the settings with Active on first." unless Messaging::SmsGateway.enabled?

    number = Messaging::Template.e164(params[:number].to_s)
    raise ArgumentError, "Enter a phone number." if number.blank?

    restriction = Messaging.country_restriction_error("smsgateway", number)
    raise ArgumentError, restriction if restriction

    message = Message.create!(direction: "outgoing", channel: "smsgateway", status: "queued",
                              to_address: number, body: "OpenAppointments test SMS")
    begin
      Messaging::SmsGateway.deliver(message)
      message.update!(status: "sent", error: nil)
      render json: { success: true }
    rescue StandardError => e
      message.update!(status: "failed", error: e.message.truncate(255))
      render json: { success: false, message: e.message }
    end
  rescue ArgumentError => e
    json_exception(e)
  end

  private

  def merged_settings
    rows = setting_row_params(setting_rows_key).to_h { |row| [ row["name"], row["value"].to_s.strip ] }
    SETTING_NAMES.index_with { |name| rows.key?(name) ? rows[name] : Setting.get(name, "") }
  end
end
