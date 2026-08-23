# Shared behavior of the per-provider messages settings pages: admin-gated and
# saves a whitelisted name list.
module MessagesProviderSettingsPage
  extend ActiveSupport::Concern

  included do
    include BackendPage
    include SettingsPage

    layout "backend"

    before_action :forbid_unless_system_settings_edit
  end

  def index
    backend_page_vars(page_title: helpers.lang("messages"), active_menu: "messages")
    html_vars(inbound_url: inbound_url)
    render :index
  end

  def save
    require_system_settings_edit!
    save_setting_rows(self.class.controller_path.to_sym, allowed_names: self.class::SETTING_NAMES)
  rescue ArgumentError => e
    settings_failed(e)
  end

  private

  # Webhook URL to paste into the SMS provider console (nil for email).
  def inbound_url
    key = self.class::CHANNEL_KEY
    return nil if key == "email"

    "#{Messaging::Template.base_url}/messages/inbound/#{key}/#{Setting.get('messages_inbound_token')}"
  end
end
