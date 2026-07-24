require "test_helper"

class SynchronizationTest < ActiveJob::TestCase
  setup do
    @provider = users(:zane)
    @appointment = appointments(:upcoming)
    @provider.settings.update!(google_sync: false, caldav_sync: false)
  end

  test "no jobs enqueued when provider has no sync enabled" do
    assert_no_enqueued_jobs only: [ GoogleSyncAppointmentJob, CaldavSyncAppointmentJob ] do
      Synchronization.appointment_saved(@appointment, nil, @provider, nil, {})
    end
  end

  test "google save enqueues a google job only" do
    @provider.settings.update!(google_sync: true)
    assert_enqueued_with(job: GoogleSyncAppointmentJob,
                         args: [ { action: "save", provider_id: @provider.id, appointment_id: @appointment.id } ]) do
      Synchronization.appointment_saved(@appointment, nil, @provider, nil, {})
    end
    assert_no_enqueued_jobs only: CaldavSyncAppointmentJob
  end

  test "both syncs enqueue both jobs" do
    @provider.settings.update!(google_sync: true, caldav_sync: true)
    assert_enqueued_jobs 1, only: GoogleSyncAppointmentJob do
      assert_enqueued_jobs 1, only: CaldavSyncAppointmentJob do
        Synchronization.appointment_saved(@appointment, nil, @provider, nil, {})
      end
    end
  end

  test "delete only enqueues when the record has a remote id" do
    @provider.settings.update!(google_sync: true)
    assert_no_enqueued_jobs only: GoogleSyncAppointmentJob do
      Synchronization.appointment_deleted(@appointment, @provider)
    end

    @appointment.update_column(:id_google_calendar, "gcal-123")
    assert_enqueued_with(job: GoogleSyncAppointmentJob,
                         args: [ { action: "delete", provider_id: @provider.id, google_event_id: "gcal-123" } ]) do
      Synchronization.appointment_deleted(@appointment, @provider)
    end
  end

  test "remove_appointment_on_provider_change clears and enqueues deletes" do
    @provider.settings.update!(google_sync: true, caldav_sync: true)
    @appointment.update_columns(id_google_calendar: "g1", id_caldav_calendar: "c1")

    assert_enqueued_jobs 2 do
      Synchronization.remove_appointment_on_provider_change(@appointment.id)
    end
    @appointment.reload
    assert_nil @appointment.id_google_calendar
    assert_nil @appointment.id_caldav_calendar
  end
end
