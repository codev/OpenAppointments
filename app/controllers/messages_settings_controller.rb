# Messages > Settings: global switch, retention and the outgoing email subject.
class MessagesSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  SETTING_NAMES = %w[messages_enabled messages_retention_days messages_email_subject messages_failure_alert
                     messages_failure_alert_emails].freeze

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("messages"), active_menu: "messages")
    script_vars(messages_settings: SETTING_NAMES.map { |name|
      { "name" => name, "value" => Setting.get(name, default_setting(name)) }
    })
    render :index
  end

  # POST /messages_settings/save
  def save
    require_system_settings_edit!
    save_setting_rows(:messages_settings, allowed_names: SETTING_NAMES) do |name, value|
      case name
      when "messages_retention_days" then value.to_i.clamp(0, 36500).to_s
      when "messages_failure_alert_emails" then normalise_emails(value)
      else value
      end
    end
  rescue ArgumentError => e
    json_exception(e)
  end

  private

  # The report list starts as every admin's address.
  def default_setting(name)
    return User.admins.pluck(:email).compact_blank.join(", ") if name == "messages_failure_alert_emails"

    Messaging::Defaults::SETTINGS[name]
  end

  # Comma separated, each a valid address; blank clears the list (admins are used).
  def normalise_emails(value)
    emails = value.to_s.split(/[\s,;]+/).reject(&:blank?)
    invalid = emails.reject { |email| email.match?(URI::MailTo::EMAIL_REGEXP) }
    raise ArgumentError, "#{helpers.lang('invalid_email')} #{invalid.join(', ')}" if invalid.any?

    emails.join(", ")
  end
end
