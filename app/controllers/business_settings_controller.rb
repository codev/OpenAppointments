# Port of EA's Business_settings controller.
class BusinessSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("settings"), active_menu: "system_settings")
    script_vars(
      business_settings: settings_rows + [ { "name" => "appointment_status_options",
                                             "value" => JSON.generate(AppointmentStatus.rows) } ],
      first_weekday: Setting.get("first_weekday"),
      time_format: Setting.get("time_format")
    )
    render :index
  end

  # POST /business_settings/save
  def save
    require_system_settings_edit!
    validate_windows!
    save_setting_rows(:business_settings) do |name, value|
      next value unless name == "appointment_status_options"

      AppointmentStatus.apply!(JSON.parse(value))
      nil
    end
  rescue ArgumentError, JSON::ParserError, ActiveRecord::RecordInvalid => e
    settings_failed(e)
  end

  # The late cancellation window cannot exceed the booking window.
  def validate_windows!
    rows = setting_row_params(:business_settings).to_h { |row| [ row["name"], row["value"].to_i ] }
    booking = rows.fetch("book_advance_timeout") { BookingWindows.minutes("book_advance_timeout") }
    late = rows.fetch("late_cancellation_timeout") { BookingWindows.late_minutes }
    raise ArgumentError, helpers.lang("late_window_exceeds_booking_window") if late > booking
  end

  # POST /business_settings/apply_global_working_plan
  def apply_global_working_plan
    require_system_settings_edit!

    working_plan = params.require(:working_plan)
    JSON.parse(working_plan) # EA check('working_plan', 'json')

    User.providers.includes(:settings).find_each do |provider|
      settings = provider.settings || provider.build_settings
      settings.update!(working_plan: working_plan)
    end

    render json: { success: true }
  rescue ArgumentError, JSON::ParserError, ActionController::ParameterMissing => e
    settings_failed(e)
  end
end
