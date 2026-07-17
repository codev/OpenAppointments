# Port of EA's Google_calendar_settings controller: the client id/secret settings
# rows only. The OAuth flow itself (Google controller) is not ported yet.
class GoogleCalendarSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  before_action :forbid_unless_system_settings_edit

  def index
    backend_page_vars(page_title: helpers.lang("settings"), active_menu: "system_settings")
    rows = [
      { "name" => "google_sync_feature", "value" => Setting.get("google_sync_feature", "0") },
      { "name" => "google_client_id", "value" => Setting.get("google_client_id", "") },
      { "name" => "google_client_secret", "value" => Setting.get("google_client_secret", "") },
      { "name" => "google_meet_link_generation", "value" => Setting.get("google_meet_link_generation", "0") },
      { "name" => "display_add_to_google_calendar", "value" => Setting.get("display_add_to_google_calendar", "1") }
    ]
    # EA filter_sensitive_settings drops the client secret row from script vars.
    script_vars(google_calendar_settings: rows.reject { |row| SENSITIVE_SETTING_NAMES.include?(row["name"]) })
    render :index
  end

  # POST /google_calendar_settings/save
  def save
    save_setting_rows(:google_calendar_settings)
  rescue ArgumentError => e
    json_exception(e)
  end
end
