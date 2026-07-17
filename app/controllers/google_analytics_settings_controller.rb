# Port of EA's Google_analytics_settings controller.
class GoogleAnalyticsSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("google_analytics"), active_menu: "system_settings")
    script_vars(google_analytics_settings: settings_rows(like: "google_analytics_"))
    render :index
  end

  # POST /google_analytics_settings/save
  def save
    require_system_settings_edit!
    save_setting_rows(:google_analytics_settings)
  rescue ArgumentError => e
    json_exception(e)
  end
end
