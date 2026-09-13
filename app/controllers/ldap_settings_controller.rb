# Port of EA's Ldap_settings controller. The settings page and save action work
# as in EA; the directory search itself is not available in this build.
class LdapSettingsController < ApplicationController
  include BackendPage
  include SettingsPage
  include UserCrud

  layout "backend"

  # EA LDAP_DEFAULT_FILTER / LDAP_DEFAULT_FIELD_MAPPING constants.
  LDAP_DEFAULT_FILTER =
    "(&(objectClass=*)(|(cn={{KEYWORD}})(sn={{KEYWORD}})(mail={{KEYWORD}})" \
    "(givenName={{KEYWORD}})(uid={{KEYWORD}})))".freeze
  LDAP_DEFAULT_FIELD_MAPPING = {
    "name" => "displayname",
    "email" => "mail",
    "phone_number" => "telephonenumber",
    "username" => "cn"
  }.freeze

  def index
    return unless require_backend_page!(:system_settings)

    backend_page_vars(page_title: helpers.lang("ldap"), active_menu: "system_settings")
    script_vars(ldap_default_filter: LDAP_DEFAULT_FILTER, ldap_default_field_mapping: LDAP_DEFAULT_FIELD_MAPPING)
    html_vars(roles: Role.order(:id).map { |role| { "id" => role.id, "name" => role.name, "slug" => role.slug } })
    render :index
  end

  # POST /ldap_settings/save
  def save
    require_system_settings_edit!
    save_setting_rows(:ldap_settings)
  rescue ArgumentError => e
    settings_failed(e)
  end

  # POST /ldap_settings/import - create a user from a directory entry (the
  # import dialog form).
  def import
    require_system_settings_edit!
    role = Role.find_by!(slug: params.require(:role_slug))
    user = User.new(params.require(:user).permit(:name, :email, :phone_number, :ldap_dn).merge(role: role))
    user.language ||= Setting.get("default_language")
    user.timezone ||= Setting.get("default_timezone")
    settings = params.fetch(:settings, {}).permit(:username, :password).to_h
    validate_unique_role_email!(User.joins(:role).where(roles: { slug: role.slug }), { "email" => user.email })
    if role.slug != Role::CUSTOMER
      validate_user_payload!({}, settings, role.slug)
      settings["working_plan"] = Setting.get("company_working_plan") if role.slug == Role::PROVIDER
    end
    User.transaction do
      user.save!
      apply_user_settings!(user, settings.merge("notifications" => true)) if role.slug != Role::CUSTOMER
    end
    redirect_to "/ldap_settings", notice: helpers.lang("user_imported")
  rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => e
    redirect_to "/ldap_settings", alert: e.message
  end

  # POST /ldap_settings/search
  def search
    require_system_settings_edit!
    raise ArgumentError, "LDAP is not available in this build."
  rescue ArgumentError => e
    settings_failed(e)
  end
end
