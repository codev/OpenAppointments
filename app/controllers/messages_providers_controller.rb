# Messages > Providers: cards per channel with the active state and a link to
# each channel's settings page.
class MessagesProvidersController < ApplicationController
  include BackendPage

  layout "backend"

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("messages"), active_menu: "messages")
    html_vars(provider_cards: provider_cards)
    render :index
  end

  private

  def provider_cards
    Messaging.channels.map do |channel|
      {
        key: channel.key,
        label: channel.label,
        settings_path: "/messages_#{channel.key == 'email' ? 'email' : channel.key}_settings",
        enabled: channel.enabled?,
        incoming: channel.enabled? && channel.incoming?
      }
    end
  end
end
