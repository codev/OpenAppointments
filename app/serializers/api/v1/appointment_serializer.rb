module Api
  module V1
    class AppointmentSerializer < BaseSerializer
      MAP = {
        "id" => "id",
        "book" => "book_datetime",
        "start" => "start_datetime",
        "end" => "end_datetime",
        "location" => "location",
        "meetingLink" => "meeting_link",
        "color" => "color",
        "status" => "status",
        "notes" => "notes",
        "hash" => "booking_hash",
        "serviceId" => "id_services",
        "providerId" => "id_users_provider",
        "customerId" => "id_users_customer",
        "googleCalendarId" => "id_google_calendar",
        "caldavCalendarId" => "id_caldav_calendar"
      }.freeze

      # EA appointments search LIKEs across these columns.
      SEARCH_COLUMNS = %w[start_datetime end_datetime location notes booking_hash].freeze
    end
  end
end
