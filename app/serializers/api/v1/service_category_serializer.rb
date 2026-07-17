module Api
  module V1
    class ServiceCategorySerializer < BaseSerializer
      MAP = {
        "id" => "id",
        "name" => "name",
        "description" => "description"
      }.freeze

      SEARCH_COLUMNS = %w[name description].freeze
    end
  end
end
