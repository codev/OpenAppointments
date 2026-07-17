module Api
  module V1
    class CustomerSerializer < BaseSerializer
      MAP = {
        "id" => "id",
        "email" => "email",
        "phone" => "phone_number",
        "address" => "address",
        "city" => "city",
        "zip" => "zip_code",
        "timezone" => "timezone",
        "language" => "language",
        "customField1" => "custom_field_1",
        "customField2" => "custom_field_2",
        "customField3" => "custom_field_3",
        "customField4" => "custom_field_4",
        "customField5" => "custom_field_5",
        "notes" => "notes",
        "ldapDn" => "ldap_dn"
      }.freeze

      SEARCH_COLUMNS = %w[users.name email phone_number mobile_number address city zip_code notes].freeze

      class << self
        # EA compat shim: single name column behind the EA v1 firstName/lastName keys.
        def encode(record)
          super.merge("firstName" => record.name, "lastName" => "")
        end

        def decode(params, base = {})
          attrs = super
          if params.key?("firstName") || params.key?("lastName")
            attrs["name"] = [ params["firstName"], params["lastName"] ].map(&:to_s).map(&:strip).compact_blank.join(" ")
          end
          attrs
        end

        def db_field(api_field)
          return "users.name" if %w[firstName lastName].include?(api_field)

          super
        end
      end
    end
  end
end
