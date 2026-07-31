# Port of EA's Altcha_settings controller. All actions require the system
# settings edit privilege (EA gates in the constructor).
class AltchaSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

  layout "backend"

  before_action :forbid_unless_system_settings_edit

  def index
    backend_page_vars(page_title: helpers.lang("settings"), active_menu: "system_settings")
    script_vars(
      altcha_settings: [
        { "name" => "captcha_provider", "value" => Setting.get("captcha_provider", "altcha") },
        { "name" => "altcha_enabled", "value" => Setting.get("altcha_enabled", "0") },
        { "name" => "captcha_login_enabled", "value" => Setting.get("captcha_login_enabled", "0") },
        { "name" => "altcha_hmac_key", "value" => Setting.get("altcha_hmac_key", "") },
        { "name" => "altcha_max_number", "value" => Setting.get("altcha_max_number", "100000") },
        { "name" => "altcha_expires", "value" => Setting.get("altcha_expires", "300") },
        { "name" => "turnstile_site_key", "value" => Setting.get("turnstile_site_key", "") },
        { "name" => "turnstile_secret_key", "value" => Setting.get("turnstile_secret_key", "") }
      ]
    )
    render :index
  end

  # POST /altcha_settings/save. Refuses to activate a provider that is not
  # fully configured (merging the payload over the stored settings).
  def save
    if (message = validation_error)
      return render json: { success: false, message: message }
    end

    save_setting_rows(:altcha_settings)
  rescue ArgumentError => e
    json_exception(e)
  end

  # POST /altcha_settings/generate_key
  def generate_key
    render json: { hmac_key: SecureRandom.hex(32) }
  end

  private

  def validation_error
    rows = setting_row_params(:altcha_settings).to_h { |row| [ row["name"], row["value"].to_s ] }
    merged = ->(name, default = "") { rows.key?(name) ? rows[name] : Setting.get(name, default) }

    active = merged.call("altcha_enabled") == "1" || merged.call("captcha_login_enabled") == "1"
    return nil unless active

    if merged.call("captcha_provider", "altcha") == "turnstile"
      helpers.lang("turnstile_keys_missing") if merged.call("turnstile_site_key").blank? ||
                                                merged.call("turnstile_secret_key").blank?
    else
      helpers.lang("altcha_hmac_key_missing") if merged.call("altcha_hmac_key").blank?
    end
  end
end
