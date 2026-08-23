# Shared behavior for the settings controllers: settings rows for script vars,
# and the save loop over the settings form (settings[name]=value) or EA's
# [{name, value}, ...] rows; HTML posts redirect back with a flash, JSON callers
# get EA's {success} shape.
module SettingsPage
  extend ActiveSupport::Concern

  # EA filter_sensitive_settings.
  SENSITIVE_SETTING_NAMES = %w[
    api_token google_client_secret ldap_password turnstile_secret_key
    messages_email_smtp_password messages_email_imap_password
    messages_twilio_auth_token messages_plivo_auth_token
    messages_textanywhere_api_key messages_inbound_token
    messages_smsgateway_password messages_smsgateway_signing_key
  ].freeze

  private

  # EA settings_model->get() row shape. like: SQL prefix filter (e.g. "api_").
  def settings_rows(like: nil, filter_sensitive: true)
    scope = Setting.order(:id)
    scope = scope.where("name LIKE ? ESCAPE '\\'", "#{Setting.sanitize_sql_like(like)}%") if like
    rows = scope.map { |setting| { "id" => setting.id, "name" => setting.name, "value" => setting.value } }
    rows.reject! { |row| SENSITIVE_SETTING_NAMES.include?(row["name"]) } if filter_sensitive
    rows
  end

  # EA save loop: persists each {name, value} row, optionally whitelisted. An
  # optional block transforms values (name, value) -> value; nil skips the row.
  def save_setting_rows(key, allowed_names: nil)
    setting_row_params(key).each do |row|
      name = row["name"]
      next unless name.is_a?(String) && name.present?
      next if allowed_names && !allowed_names.include?(name)

      value = row["value"].to_s
      value = yield(name, value) if block_given?
      Setting.set(name, value) unless value.nil?
    end

    settings_saved
  end

  # The settings form (settings[...]) gets a redirect with a flash; EA's row
  # format callers get the {success} JSON they expect.
  def settings_saved
    return render json: { success: true } unless settings_form_post?

    redirect_to url_for(action: :index), notice: helpers.lang("settings_saved")
  end

  def settings_failed(error)
    return json_exception(error) unless settings_form_post?

    redirect_to url_for(action: :index), alert: error.message
  end

  def settings_form_post? = params[:settings].respond_to?(:to_unsafe_h)

  # The settings form posts settings[name]=value; EA's jQuery posted arrays of
  # objects (key[0][name]=...), which Rack parses into a hash keyed "0", "1", ...
  # Both become an array of {name, value} hashes.
  def setting_row_params(key)
    if settings_form_post?
      # A password field left empty keeps the stored secret.
      return params[:settings].to_unsafe_h.filter_map { |name, value|
        next if value.blank? && SENSITIVE_SETTING_NAMES.include?(name.to_s)

        { "name" => name.to_s, "value" => value }
      }
    end

    rows = params[key]
    return [] if rows.blank?

    rows = rows.values if rows.respond_to?(:values)
    rows.map { |row| row.respond_to?(:permit) ? row.permit(:id, :name, :value).to_h : row }
  end

  # EA settings save actions raise on missing edit privilege (json_exception -> 500).
  def require_system_settings_edit!
    return if can?(:edit, :system_settings)

    raise ArgumentError, "You do not have the required permissions for this task."
  end

  # EA Altcha/Jitsi/Google_calendar settings controllers gate every action on the
  # edit privilege in the constructor (403, no login redirect).
  def forbid_unless_system_settings_edit
    head :forbidden if cannot?(:edit, :system_settings)
  end
end
