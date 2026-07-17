module Api
  module V1
    # Shared base for provider/secretary/admin serializers. Encodes the common user
    # scalar fields plus a settings sub-object; decode splits API params back into
    # user columns, a nested settings hash, and (per subclass) services/providers arrays.
    class UserSerializer < BaseSerializer
      MAP = {
        "id" => "id",
        "firstName" => "first_name",
        "lastName" => "last_name",
        "email" => "email",
        "mobile" => "mobile_number",
        "phone" => "phone_number",
        "address" => "address",
        "city" => "city",
        "state" => "state",
        "zip" => "zip_code",
        "timezone" => "timezone",
        "language" => "language",
        "notes" => "notes",
        "ldapDn" => "ldap_dn",
        "roleId" => "id_roles"
      }.freeze

      SEARCH_COLUMNS = %w[first_name last_name email phone_number mobile_number address city zip_code notes].freeze

      class << self
        def encode(record)
          payload = super
          payload["settings"] = settings_encode(record.settings) if record.settings
          payload
        end

        # Simple settings sub-object (secretaries/admins).
        def settings_encode(settings)
          {
            "username" => settings.username,
            "notifications" => bool(settings.notifications),
            "calendarView" => settings.calendar_view
          }
        end

        def decode(params, base = {})
          attrs = super
          attrs["settings"] = settings_decode(params["settings"]) if params.key?("settings")
          attrs
        end

        def settings_decode(settings)
          return {} if settings.blank?

          out = {}
          out["username"] = settings["username"] if settings.key?("username")
          out["password"] = settings["password"] if settings.key?("password")
          out["calendar_view"] = settings["calendarView"] if settings.key?("calendarView")
          out["notifications"] = settings["notifications"] if settings.key?("notifications")
          out
        end

        def bool(value)
          ActiveModel::Type::Boolean.new.cast(value) || false
        end
      end
    end
  end
end
