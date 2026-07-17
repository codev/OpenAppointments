# Port of EA's Matomo_analytics_settings controller.
class MatomoAnalyticsSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("matomo_analytics"), active_menu: "system_settings")
    script_vars(matomo_analytics_settings: settings_rows(like: "matomo_analytics_"))
    render :index
  end

  # POST /matomo_analytics_settings/save
  def save
    require_system_settings_edit!
    save_setting_rows(:matomo_analytics_settings)
  rescue ArgumentError => e
    json_exception(e)
  end
end
