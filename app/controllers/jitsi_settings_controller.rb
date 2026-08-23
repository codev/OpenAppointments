# Port of EA's Jitsi_settings controller.
class JitsiSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  before_action :forbid_unless_system_settings_edit

  def index
    backend_page_vars(page_title: helpers.lang("settings"), active_menu: "system_settings")
    render :index
  end

  # POST /jitsi_settings/save
  def save
    save_setting_rows(:jitsi_settings)
  rescue ArgumentError => e
    settings_failed(e)
  end
end
