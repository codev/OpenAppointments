# Umami Analytics settings page (integrations hub).
class UmamiAnalyticsSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("umami_analytics"), active_menu: "system_settings")
    render :index
  end

  # POST /umami_analytics_settings/save
  def save
    require_system_settings_edit!
    save_setting_rows(:umami_analytics_settings) { |_name, value| value.strip }
  rescue ArgumentError => e
    settings_failed(e)
  end
end
