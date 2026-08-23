# CrudPage for user records (admins, assistants, providers): role scope, settings
# (username, password with confirmation, notifications), picture, and EA's
# password and unique email rules.
module UserPage
  extend ActiveSupport::Concern
  include CrudPage
  include RecordPicture
  include UserCrud

  USER_FIELDS = %i[name email phone_number mobile_number address city state zip_code notes timezone language
                   ldap_dn is_private].freeze
  SETTING_FIELDS = %i[username password password_confirmation notifications].freeze

  private

  def record_scope = User.where(role: role).includes(:settings).order(:name)

  def role = Role.find_by!(slug: self.class::PAGE[:role])

  def filter(scope, keyword)
    return scope if keyword.blank?

    pattern = "%#{User.sanitize_sql_like(keyword)}%"
    scope.where(<<~SQL.squish, pattern: pattern)
      users.name LIKE :pattern OR email LIKE :pattern
      OR phone_number LIKE :pattern OR mobile_number LIKE :pattern OR address LIKE :pattern
      OR city LIKE :pattern OR state LIKE :pattern OR zip_code LIKE :pattern OR notes LIKE :pattern
    SQL
  end

  def user_fields = params.require(controller_name.singularize)

  def record_params
    permitted = user_fields.permit(*USER_FIELDS)
    permitted.delete(:ldap_dn) unless Setting.get("ldap_is_active").to_s == "1"
    permitted
  end

  def setting_params
    user_fields.fetch(:settings, {}).permit(*SETTING_FIELDS).to_h.with_indifferent_access
  end

  # Checks the jQuery page used to do client side, so the form re-renders with a message.
  def before_save
    settings = setting_params
    if settings.key?(:password_confirmation) && settings[:password].to_s != settings[:password_confirmation].to_s
      raise ArgumentError, helpers.lang("passwords_mismatch")
    end

    validate_user_payload!({ "id" => @record.id }, settings.slice(:password).stringify_keys, self.class::PAGE[:role])
    validate_unique_role_email!(record_scope, { "email" => @record.email, "id" => @record.id })
    username = settings[:username].presence
    if username && UserSetting.where(username: username).where.not(id_users: @record.id).exists?
      raise ArgumentError, helpers.lang("username_already_exists")
    end
  end

  def after_save
    settings = setting_params.except(:password_confirmation)
    settings[:notifications] = ActiveModel::Type::Boolean.new.cast(settings[:notifications]) if settings.key?(:notifications)
    apply_user_settings!(@record, settings.stringify_keys)
    save_record_picture(@record, user_fields)
  end
end
