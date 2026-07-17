# Outbound push of an appointment save/delete to a provider's Google Calendar.
# Auth/token failures are discarded (EA disables sync gracefully rather than looping).
class GoogleSyncAppointmentJob < ApplicationJob
  queue_as :default

  discard_on GoogleCalendarGateway::AuthError
  discard_on ActiveJob::DeserializationError
  retry_on Google::Apis::ServerError, wait: :polynomially_longer, attempts: 3

  def perform(action:, provider_id:, appointment_id: nil, google_event_id: nil)
    provider = User.find_by(id: provider_id)
    return unless provider&.settings&.google_sync

    gateway = GoogleCalendarGateway.new(redirect_uri: SyncUrls.google_callback)

    case action
    when "save"
      appointment = Appointment.find_by(id: appointment_id)
      return unless appointment

      push_save(gateway, provider, appointment)
    when "delete"
      gateway.delete_appointment(provider, google_event_id) if google_event_id.present?
    end
  end

  private

  def push_save(gateway, provider, appointment)
    company = Setting.get("company_name")
    service = appointment.service
    customer = appointment.customer

    if appointment.id_google_calendar.blank?
      event = gateway.add_appointment(provider, appointment, service, customer, company)
      appointment.update_column(:id_google_calendar, event.id)
    else
      gateway.update_appointment(provider, appointment, service, customer, company)
    end
  end
end
