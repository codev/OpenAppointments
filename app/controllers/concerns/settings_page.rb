# Shared behavior for EA settings controllers: settings rows for script vars and
# the EA save loop over [{name, value}, ...] payloads.
module SettingsPage
  extend ActiveSupport::Concern

  # EA filter_sensitive_settings.
  SENSITIVE_SETTING_NAMES = %w[
    api_token google_client_secret ldap_password turnstile_secret_key
    messages_email_smtp_password messages_email_imap_password
    messages_twilio_auth_token messages_plivo_auth_token
    messages_textanywhere_api_key messages_inbound_token
  ].freeze

  private

  # EA settings_model->get() row shape. like: SQL prefix filter (e.g. "api_").
  def settings_rows(like: nil, filter_sensitive: true)
    scope = Setting.order(:id)
    scope = scope.where("name LIKE ?", "#{Setting.sanitize_sql_like(like)}%") if like
    rows = scope.map { |setting| { "id" => setting.id, "name" => setting.name, "value" => setting.value } }
    rows.reject! { |row| SENSITIVE_SETTING_NAMES.include?(row["name"]) } if filter_sensitive
    rows
  end

  # EA save loop: persists each {name, value} row, optionally whitelisted. An
  # optional block transforms values (name, value) -> value.
  def save_setting_rows(key, allowed_names: nil)
    setting_row_params(key).each do |row|
      name = row["name"]
      next unless name.is_a?(String) && name.present?
      next if allowed_names && !allowed_names.include?(name)

      value = row["value"].to_s
      value = yield(name, value) if block_given?
      Setting.set(name, value)
    end

    render json: { success: true }
  end

  # jQuery posts arrays of objects as key[0][name]=..., which Rack parses into a
  # hash keyed "0", "1", ... Normalize to an array of plain hashes.
  def setting_row_params(key)
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
