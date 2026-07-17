module Api
  module V1
    class BlockedPeriodSerializer < BaseSerializer
      MAP = {
        "id" => "id",
        "name" => "name",
        "start" => "start_datetime",
        "end" => "end_datetime",
        "notes" => "notes"
      }.freeze

      SEARCH_COLUMNS = %w[name notes].freeze
    end
  end
end
