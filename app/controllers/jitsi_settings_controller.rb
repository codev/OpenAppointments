# Port of EA's Jitsi_settings controller.
class JitsiSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  before_action :forbid_unless_system_settings_edit

  def index
    backend_page_vars(page_title: helpers.lang("settings"), active_menu: "system_settings")
    script_vars(
      jitsi_settings: [
        { "name" => "jitsi_enabled", "value" => Setting.get("jitsi_enabled", "0") }
      ]
    )
    render :index
  end

  # POST /jitsi_settings/save
  def save
    save_setting_rows(:jitsi_settings)
  rescue ArgumentError => e
    json_exception(e)
  end
end
