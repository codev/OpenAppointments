module Api
  module V1
    # breaks is exposed as a decoded JSON array, stored as a JSON string.
    class WorkingPlanExceptionSerializer < BaseSerializer
      MAP = {
        "id" => "id",
        "startDate" => "start_date",
        "endDate" => "end_date",
        "startTime" => "start_time",
        "endTime" => "end_time",
        "breaks" => "breaks",
        "providerId" => "id_users_provider"
      }.freeze

      SEARCH_COLUMNS = [].freeze

      def self.encode(record)
        super.merge("breaks" => record.break_list)
      end

      def self.decode(params, base = {})
        attrs = super
        attrs["breaks"] = params["breaks"].to_json if params.key?("breaks")
        attrs
      end
    end
  end
end
