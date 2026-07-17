# Port of EA's Booking_settings controller.
class BookingSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  RICH_TEXT_SETTINGS = %w[disable_booking_message].freeze

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("settings"), active_menu: "system_settings")
    script_vars(booking_settings: settings_rows)
    render :index
  end

  # POST /booking_settings/save
  def save
    require_system_settings_edit!
    save_setting_rows(:booking_settings) do |name, value|
      if name.start_with?("label_custom_field_")
        helpers.strip_tags(value)
      elsif RICH_TEXT_SETTINGS.include?(name)
        helpers.sanitize(value)
      else
        value
      end
    end
  rescue ArgumentError => e
    json_exception(e)
  end
end
