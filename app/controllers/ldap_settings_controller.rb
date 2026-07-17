# Port of EA's Ldap_settings controller. The settings page and save action work
# as in EA; the directory search itself is not available in this build.
class LdapSettingsController < ApplicationController
  include BackendPage
  include SettingsPage

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
    script_vars(
      ldap_settings: settings_rows(like: "ldap_"),
      ldap_default_filter: LDAP_DEFAULT_FILTER,
      ldap_default_field_mapping: LDAP_DEFAULT_FIELD_MAPPING
    )
    html_vars(roles: Role.order(:id).map { |role| { "id" => role.id, "name" => role.name, "slug" => role.slug } })
    render :index
  end

  # POST /ldap_settings/save
  def save
    require_system_settings_edit!
    save_setting_rows(:ldap_settings)
  rescue ArgumentError => e
    json_exception(e)
  end

  # POST /ldap_settings/search
  def search
    require_system_settings_edit!
    raise ArgumentError, "LDAP is not available in this build."
  rescue ArgumentError => e
    json_exception(e)
  end
end
