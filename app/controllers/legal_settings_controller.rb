# Port of EA's Legal_settings controller.
class LegalSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  LEGAL_CONTENT_SETTINGS = %w[booking_notice_content cookie_notice_content terms_and_conditions_content
                              privacy_policy_content].freeze

  # The editor writes alignment as an inline style; the sanitiser keeps only
  # safe CSS properties within it.
  LEGAL_CONTENT_ATTRIBUTES = (Rails::HTML5::SafeListSanitizer.allowed_attributes + [ "style" ]).freeze

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("settings"), active_menu: "system_settings")
    render :index
  end

  # POST /legal_settings/save
  def save
    require_system_settings_edit!
    save_setting_rows(:legal_settings) do |name, value|
      LEGAL_CONTENT_SETTINGS.include?(name) ? helpers.sanitize(value, attributes: LEGAL_CONTENT_ATTRIBUTES) : value
    end
  rescue ArgumentError => e
    settings_failed(e)
  end
end
