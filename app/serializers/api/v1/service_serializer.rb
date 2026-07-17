module Api
  module V1
    class ServiceSerializer < BaseSerializer
      MAP = {
        "id" => "id",
        "name" => "name",
        "duration" => "duration",
        "price" => "price",
        "currency" => "currency",
        "description" => "description",
        "location" => "location",
        "color" => "color",
        "slotInterval" => "slot_interval",
        "attendantsNumber" => "attendants_number",
        "isPrivate" => "is_private",
        "serviceCategoryId" => "id_service_categories"
      }.freeze

      SEARCH_COLUMNS = %w[name description].freeze
    end
  end
end
