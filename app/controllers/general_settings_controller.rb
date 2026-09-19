# Port of EA's General_settings controller.
class GeneralSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  ALLOWED_SETTINGS = %w[
    company_name company_email company_link company_logo
    company_working_plan book_advance_timeout default_timezone timezone_support default_language default_country_code
    date_format time_format first_weekday require_phone_number
    display_booking_notice_time_step display_booking_notice_info_step booking_notice_content
    display_cookie_notice cookie_notice_content display_terms_and_conditions
    terms_and_conditions_content display_privacy_policy privacy_policy_content
    provider_label provider_label_plural service_label service_label_plural data_retention_days
  ].freeze

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("settings"), active_menu: "system_settings")
    render :index
  end

  # POST /general_settings/save. The logo arrives as a file and is stored as a
  # data URL, as the jQuery page did; remove_company_logo clears it.
  def save
    require_system_settings_edit!
    save_company_logo
    save_setting_rows(:general_settings, allowed_names: ALLOWED_SETTINGS)
  rescue ArgumentError => e
    settings_failed(e)
  end

  private

  def save_company_logo
    if ActiveModel::Type::Boolean.new.cast(params[:remove_company_logo])
      Setting.set("company_logo", "")
    elsif params[:company_logo].respond_to?(:read)
      file = params[:company_logo]
      PictureUpload.validate!(file)
      Setting.set("company_logo", "data:#{file.content_type};base64,#{Base64.strict_encode64(file.read)}")
    end
  end
end
