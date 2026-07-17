# Port of EA's General_settings controller.
class GeneralSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  ALLOWED_SETTINGS = %w[
    company_name company_email company_link company_logo company_color
    company_working_plan book_advance_timeout default_timezone default_language
    theme date_format time_format first_weekday require_phone_number
    display_cookie_notice cookie_notice_content display_terms_and_conditions
    terms_and_conditions_content display_privacy_policy privacy_policy_content
  ].freeze

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("settings"), active_menu: "system_settings")
    script_vars(general_settings: settings_rows)
    html_vars(
      available_languages: Localization.available_languages,
      available_themes: available_themes
    )
    render :index
  end

  # POST /general_settings/save
  def save
    require_system_settings_edit!
    save_setting_rows(:general_settings, allowed_names: ALLOWED_SETTINGS)
  rescue ArgumentError => e
    json_exception(e)
  end

  private

  def available_themes
    Rails.root.glob("app/assets/builds/themes/*.css").map { |path| path.basename(".css").to_s }.sort
  end
end
