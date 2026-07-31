# Port of EA's Integrations controller (settings hub page).
class IntegrationsController < ApplicationController
  include BackendPage

  layout "backend"

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("integrations"), active_menu: "system_settings")
    @statuses = {
      captcha: Captcha.for_customers.present? || Captcha.for_login.present?,
      google_calendar: Setting.get("google_sync_feature") == "1",
      embedding: Setting.get("allow_iframe_embedding") == "1",
      webhooks: Webhook.count,
      umami_analytics: Setting.get("umami_analytics_url").to_s.present? &&
                       Setting.get("umami_analytics_website_id").to_s.present?,
      google_analytics: Setting.get("google_analytics_code").to_s.present?,
      matomo_analytics: Setting.get("matomo_analytics_url").to_s.present?,
      api: Setting.get("api_token").to_s.present?,
      ldap: Setting.get("ldap_is_active") == "1",
      jitsi: Setting.get("jitsi_enabled") == "1"
    }
    render :index
  end
end
