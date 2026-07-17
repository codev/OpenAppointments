module Api
  module V1
    # EA's unavailabilities API only fires webhooks (no sync, no notifications).
    class UnavailabilitiesController < ResourceController
      self.serializer_class = UnavailabilitySerializer
      self.save_webhook = Webhooks::UNAVAILABILITY_SAVE
      self.delete_webhook = Webhooks::UNAVAILABILITY_DELETE

      private

      def base_scope = Appointment.unavailabilities

      def with_loaders
        { "provider" => ->(record) { raw_row(record.provider) } }
      end

      def build_record(attrs)
        record = Appointment.new(serializer_class.decode(attrs))
        record.is_unavailability = true
        record.book_datetime ||= Time.now
        record
      end
    end
  end
end
