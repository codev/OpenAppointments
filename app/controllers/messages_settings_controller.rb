# Messages > Settings: global switch, retention and the outgoing email subject.
class MessagesSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  SETTING_NAMES = %w[messages_enabled messages_retention_days messages_email_subject].freeze

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("messages"), active_menu: "messages")
    script_vars(messages_settings: SETTING_NAMES.map { |name|
      { "name" => name, "value" => Setting.get(name, Messaging::Defaults::SETTINGS[name]) }
    })
    render :index
  end

  # POST /messages_settings/save
  def save
    require_system_settings_edit!
    save_setting_rows(:messages_settings, allowed_names: SETTING_NAMES) do |name, value|
      name == "messages_retention_days" ? value.to_i.clamp(0, 36500).to_s : value
    end
  rescue ArgumentError => e
    json_exception(e)
  end
end
