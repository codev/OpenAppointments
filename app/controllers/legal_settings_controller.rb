# Port of EA's Legal_settings controller.
class LegalSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("settings"), active_menu: "system_settings")
    render :index
  end

  # POST /legal_settings/save; the rich text rows are sanitised by Setting.set.
  def save
    require_system_settings_edit!
    save_setting_rows(:legal_settings)
  rescue ArgumentError => e
    settings_failed(e)
  end
end
