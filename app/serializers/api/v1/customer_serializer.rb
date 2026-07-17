module Api
  module V1
    class CustomerSerializer < BaseSerializer
      MAP = {
        "id" => "id",
        "firstName" => "first_name",
        "lastName" => "last_name",
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

      SEARCH_COLUMNS = %w[first_name last_name email phone_number mobile_number address city zip_code notes].freeze
    end
  end
end
