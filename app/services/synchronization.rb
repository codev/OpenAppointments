# External calendar sync dispatcher (EA Synchronization library). Enqueues outbound
# Google/CalDAV jobs when the appointment's provider has that sync enabled. Runs after
# the DB write; the jobs push to the remote calendars and store back the event ids.
module Synchronization
  module_function

  def appointment_saved(appointment, _service, provider, _customer, _settings)
    enqueue_save(appointment, provider)
  end

  def appointment_deleted(appointment, provider)
    enqueue_delete(appointment, provider)
  end

  def unavailability_saved(unavailability, provider)
    enqueue_save(unavailability, provider)
  end

  def unavailability_deleted(unavailability, provider)
    enqueue_delete(unavailability, provider)
  end

  # EA removes the event from the old provider's calendar when an appointment moves.
  def remove_appointment_on_provider_change(appointment_id)
    appointment = Appointment.find_by(id: appointment_id)
    return unless appointment

    if appointment.id_google_calendar.present?
      GoogleSyncAppointmentJob.perform_later(action: "delete", provider_id: appointment.id_users_provider,
                                             google_event_id: appointment.id_google_calendar)
      appointment.update_column(:id_google_calendar, nil)
    end
    return if appointment.id_caldav_calendar.blank?

    CaldavSyncAppointmentJob.perform_later(action: "delete", provider_id: appointment.id_users_provider,
                                           caldav_event_id: appointment.id_caldav_calendar)
    appointment.update_column(:id_caldav_calendar, nil)
  end

  def enqueue_save(record, provider)
    return unless provider&.settings

    if provider.settings.google_sync
      GoogleSyncAppointmentJob.perform_later(action: "save", provider_id: provider.id, appointment_id: record.id)
    end
    return unless provider.settings.caldav_sync

    CaldavSyncAppointmentJob.perform_later(action: "save", provider_id: provider.id, appointment_id: record.id)
  end

  def enqueue_delete(record, provider)
    return unless provider&.settings

    if provider.settings.google_sync && record.id_google_calendar.present?
      GoogleSyncAppointmentJob.perform_later(action: "delete", provider_id: provider.id,
                                             google_event_id: record.id_google_calendar)
    end
    return unless provider.settings.caldav_sync && record.id_caldav_calendar.present?

    CaldavSyncAppointmentJob.perform_later(action: "delete", provider_id: provider.id,
                                           caldav_event_id: record.id_caldav_calendar)
  end
end
