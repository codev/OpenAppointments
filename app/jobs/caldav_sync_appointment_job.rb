# Outbound push of an appointment save/delete to a provider's CalDAV calendar.
class CaldavSyncAppointmentJob < ApplicationJob
  queue_as :default

  discard_on CaldavGateway::AuthError
  discard_on ActiveJob::DeserializationError
  retry_on Net::OpenTimeout, Net::ReadTimeout, wait: :polynomially_longer, attempts: 3

  def perform(action:, provider_id:, appointment_id: nil, caldav_event_id: nil)
    provider = User.find_by(id: provider_id)
    return unless provider&.settings&.caldav_sync

    gateway = CaldavGateway.new

    case action
    when "save"
      appointment = Appointment.find_by(id: appointment_id)
      return unless appointment

      event_id = gateway.save_appointment(provider, appointment, appointment.service, appointment.customer)
      appointment.update_column(:id_caldav_calendar, event_id) if appointment.id_caldav_calendar.blank?
    when "delete"
      gateway.delete_event(provider, caldav_event_id) if caldav_event_id.present?
    end
  end
end
