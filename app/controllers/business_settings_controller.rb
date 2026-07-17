# Port of EA's Business_settings controller.
class BusinessSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("settings"), active_menu: "system_settings")
    script_vars(
      business_settings: settings_rows,
      first_weekday: Setting.get("first_weekday"),
      time_format: Setting.get("time_format")
    )
    render :index
  end

  # POST /business_settings/save
  def save
    require_system_settings_edit!
    save_setting_rows(:business_settings)
  rescue ArgumentError => e
    json_exception(e)
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
    json_exception(e)
  end
end
