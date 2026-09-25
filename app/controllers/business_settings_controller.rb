# Port of EA's Business_settings controller.
class BusinessSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("settings"), active_menu: "system_settings")
    script_vars(first_weekday: Setting.get("first_weekday"), time_format: Setting.get("time_format"))
    html_vars(appointment_status_options: JSON.generate(AppointmentStatus.rows))
    render :index
  end

  # POST /business_settings/save
  def save
    require_system_settings_edit!
    merge_minutes_fields
    save_setting_rows(:business_settings) do |name, value|
      if name == "booking_release_time"
        raise ArgumentError, helpers.lang("invalid_datetime") unless value.to_s.match?(BookingWindows::RELEASE_TIME_FORMAT)

        next value
      end
      next value unless name == "appointment_status_options"

      AppointmentStatus.apply!(JSON.parse(value))
      nil
    end
  rescue ArgumentError, JSON::ParserError, ActiveRecord::RecordInvalid => e
    settings_failed(e)
  end

  # The windows are typed as hours + minutes (minutes[name][hours|minutes]).
  def merge_minutes_fields
    return unless settings_form_post? && params[:minutes].respond_to?(:each)

    params[:minutes].each do |name, parts|
      params[:settings][name] = (parts[:hours].to_i * 60 + parts[:minutes].to_i).to_s
    end
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
