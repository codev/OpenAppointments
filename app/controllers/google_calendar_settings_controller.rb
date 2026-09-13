# Port of EA's Google_calendar_settings controller: the client id/secret settings
# rows only. The OAuth flow itself (Google controller) is not ported yet.
class GoogleCalendarSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  before_action :forbid_unless_system_settings_edit

  def index
    backend_page_vars(page_title: helpers.lang("settings"), active_menu: "system_settings")
    render :index
  end

  # POST /google_calendar_settings/save
  def save
    save_setting_rows(:google_calendar_settings)
  rescue ArgumentError => e
    settings_failed(e)
  end
end
