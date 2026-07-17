# Port of EA's Legal_settings controller.
class LegalSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  LEGAL_CONTENT_SETTINGS = %w[cookie_notice_content terms_and_conditions_content
                              privacy_policy_content].freeze

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("settings"), active_menu: "system_settings")
    script_vars(legal_settings: settings_rows)
    render :index
  end

  # POST /legal_settings/save
  def save
    require_system_settings_edit!
    save_setting_rows(:legal_settings) do |name, value|
      LEGAL_CONTENT_SETTINGS.include?(name) ? helpers.sanitize(value) : value
    end
  rescue ArgumentError => e
    json_exception(e)
  end
end
