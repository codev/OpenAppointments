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
    save_setting_rows(self.class.controller_path.to_sym, allowed_names: self.class::SETTING_NAMES + [ default_switch_name ]) do |name, value|
      next value unless name == default_switch_name

      apply_default_switch(value)
      nil
    end
  rescue ArgumentError => e
    settings_failed(e)
  end

  private

  # The page's Default switch posts as messages_<key>_default; it is not a
  # setting of its own but writes the one messages_default_channel row.
  def default_switch_name = "messages_#{self.class::CHANNEL_KEY}_default"

  # On makes this provider the default (any other loses it); off clears the
  # default only when it is this provider.
  def apply_default_switch(value)
    key = self.class::CHANNEL_KEY
    if value == "1"
      Setting.set("messages_default_channel", key)
    elsif Messaging.default_channel_key == key
      Setting.set("messages_default_channel", "")
    end
  end

  # Webhook URL to paste into the SMS provider console (nil for email).
  def inbound_url
    key = self.class::CHANNEL_KEY
    return nil if key == "email"

    "#{Messaging::Template.base_url}/messages/inbound/#{key}/#{Setting.get('messages_inbound_token')}"
  end
end
