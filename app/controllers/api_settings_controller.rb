# Port of EA's Api_settings controller.
class ApiSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("api"), active_menu: "system_settings")
    # EA passes the api_% rows unfiltered so the token can be edited on this page.
    script_vars(api_settings: settings_rows(like: "api_", filter_sensitive: false))
    render :index
  end

  # POST /api_settings/save
  def save
    require_system_settings_edit!
    save_setting_rows(:api_settings)
  rescue ArgumentError => e
    json_exception(e)
  end
end
