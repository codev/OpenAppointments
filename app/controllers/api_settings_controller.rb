# Port of EA's Api_settings controller.
class ApiSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("api"), active_menu: "system_settings")
    render :index
  end

  # The token is shown on this page, so it can be blanked to revoke it.
  def shown_secrets = %w[api_token]

  # POST /api_settings/save
  def save
    require_system_settings_edit!
    save_setting_rows(:api_settings)
  rescue ArgumentError => e
    settings_failed(e)
  end
end
