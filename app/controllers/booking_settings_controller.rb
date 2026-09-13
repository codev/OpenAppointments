# Port of EA's Booking_settings controller.
class BookingSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  RICH_TEXT_SETTINGS = %w[disable_booking_message].freeze

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("settings"), active_menu: "system_settings")
    render :index
  end

  # POST /booking_settings/save
  def save
    require_system_settings_edit!
    validate_field_rules! if settings_form_post? # the row API posts partial sets
    save_setting_rows(:booking_settings) do |name, value|
      if name.start_with?("label_custom_field_")
        helpers.strip_tags(value)
      elsif RICH_TEXT_SETTINGS.include?(name)
        helpers.sanitize(value)
      else
        value
      end
    end
    reconcile_contact_requirements
  rescue ArgumentError => e
    settings_failed(e)
  end

  private

  # The phone-or-email rule and the individual email/phone require flags are
  # mutually exclusive; the rule wins over conflicting input.
  # The jQuery page refused a form with no field shown or none required (the
  # phone-or-email rule counts); merged over the stored settings.
  def validate_field_rules!
    rows = setting_row_params(:booking_settings).to_h { |row| [ row["name"], row["value"].to_s ] }
    value = ->(name) { rows.fetch(name) { Setting.get(name, "0").to_s } }
    fields = %w[email phone_number address city zip_code notes custom_field_1 custom_field_2 custom_field_3 custom_field_4 custom_field_5]
    raise ArgumentError, helpers.lang("at_least_one_field") if fields.none? { |f| value.call("display_#{f}") == "1" }
    required = fields.any? { |f| value.call("require_#{f}") == "1" } || value.call("require_phone_or_email") == "1"
    raise ArgumentError, helpers.lang("at_least_one_field_required") unless required
  end

  def reconcile_contact_requirements
    if Setting.get("require_phone_or_email", "1").to_s == "1"
      Setting.set("require_email", "0")
      Setting.set("require_phone_number", "0")
    end
  end
end
