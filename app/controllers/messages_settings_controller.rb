# Messages > Settings: global switch, retention and the outgoing email subject.
class MessagesSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  SETTING_NAMES = %w[messages_enabled messages_retention_days messages_email_subject messages_failure_alert
                     messages_failure_alert_emails messages_intercept_email messages_intercept_phone].freeze

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("messages"), active_menu: "messages")
    # The report list starts as every admin's address.
    html_vars(failure_alert_emails: Setting.get("messages_failure_alert_emails",
                                                User.admins.pluck(:email).compact_blank.join(", ")))
    render :index
  end

  # POST /messages_settings/save
  def save
    require_system_settings_edit!
    intercept = intercept_values
    save_setting_rows(:messages_settings, allowed_names: SETTING_NAMES) do |name, value|
      case name
      when "messages_retention_days" then value.to_i.clamp(0, 36500).to_s
      when "messages_failure_alert_emails" then normalise_emails(value)
      when "messages_intercept_email", "messages_intercept_phone" then intercept.fetch(name, value)
      else value
      end
    end
  rescue ArgumentError => e
    settings_failed(e)
  end

  private

  # Debug needs a valid intercept email and phone (stored in E.164); On and Off
  # clear both. Row-format callers post no settings hash and keep what they send.
  def intercept_values
    return {} unless settings_form_post?
    return { "messages_intercept_email" => "", "messages_intercept_phone" => "" } unless params[:settings][:messages_enabled] == "debug"

    email = params[:settings][:messages_intercept_email].to_s.strip
    phone = Messaging::Template.e164(params[:settings][:messages_intercept_phone].to_s).to_s
    raise ArgumentError, helpers.lang("messages_intercept_required") if email.blank? || phone.blank?
    raise ArgumentError, helpers.lang("invalid_email") unless email.match?(URI::MailTo::EMAIL_REGEXP)
    raise ArgumentError, helpers.lang("invalid_phone") unless phone.match?(/\A\+\d{8,15}\z/)

    { "messages_intercept_email" => email, "messages_intercept_phone" => phone }
  end

  # Comma separated, each a valid address; blank clears the list (admins are used).
  def normalise_emails(value)
    emails = value.to_s.split(/[\s,;]+/).reject(&:blank?)
    invalid = emails.reject { |email| email.match?(URI::MailTo::EMAIL_REGEXP) }
    raise ArgumentError, "#{helpers.lang('invalid_email')} #{invalid.join(', ')}" if invalid.any?

    emails.join(", ")
  end
end
