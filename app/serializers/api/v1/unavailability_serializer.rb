module Api
  module V1
    class UnavailabilitySerializer < BaseSerializer
      MAP = {
        "id" => "id",
        "book" => "book_datetime",
        "start" => "start_datetime",
        "end" => "end_datetime",
        "location" => "location",
        "color" => "color",
        "status" => "status",
        "notes" => "notes",
        "hash" => "booking_hash",
        "providerId" => "id_users_provider",
        "googleCalendarId" => "id_google_calendar"
      }.freeze

      SORT_OVERRIDES = {
        "status" => "(SELECT name FROM appointment_statuses WHERE appointment_statuses.id = appointments.status_id)"
      }.freeze

      SEARCH_COLUMNS = %w[start_datetime end_datetime location notes booking_hash].freeze
    end
  end
end
