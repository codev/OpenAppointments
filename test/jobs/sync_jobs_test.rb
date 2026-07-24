require "test_helper"
require "webmock/minitest"

class SyncJobsTest < ActiveJob::TestCase
  setup do
    @provider = users(:zane)
    @appointment = appointments(:upcoming)
  end

  # Fake gateway recording the add_appointment call and returning an event with an id.
  class FakeGoogleGateway
    attr_reader :added

    def initialize = @added = false
    def add_appointment(*) = (@added = true) && Struct.new(:id).new("gcal-new")
  end

  def stub_google_gateway(fake)
    GoogleCalendarGateway.define_singleton_method(:new) { |*| fake }
    yield
  ensure
    GoogleCalendarGateway.singleton_class.remove_method(:new)
  end

  test "google job stores the returned event id on a new appointment" do
    @provider.settings.update!(google_sync: true)
    fake = FakeGoogleGateway.new
    stub_google_gateway(fake) do
      GoogleSyncAppointmentJob.perform_now(action: "save", provider_id: @provider.id,
                                           appointment_id: @appointment.id)
    end
    assert fake.added
    assert_equal "gcal-new", @appointment.reload.id_google_calendar
  end

  test "google job is a no-op when provider sync disabled" do
    @provider.settings.update!(google_sync: false)
    stub_google_gateway(->(*) { flunk "gateway should not be built" }) do
      GoogleSyncAppointmentJob.perform_now(action: "save", provider_id: @provider.id,
                                           appointment_id: @appointment.id)
    end
    assert_nil @appointment.reload.id_google_calendar
  end

  test "caldav job PUTs the ICS and stores the event id" do
    @provider.settings.update!(caldav_sync: true, caldav_url: "https://dav.example.org/cal",
                               caldav_username: "u", caldav_password: "p")
    stub = stub_request(:put, %r{https://dav\.example\.org/cal/.+\.ics}).to_return(status: 201)

    CaldavSyncAppointmentJob.perform_now(action: "save", provider_id: @provider.id,
                                         appointment_id: @appointment.id)
    assert_requested stub
    assert @appointment.reload.id_caldav_calendar.present?
  end

  test "caldav delete issues a DELETE" do
    @provider.settings.update!(caldav_sync: true, caldav_url: "https://dav.example.org/cal",
                               caldav_username: "u", caldav_password: "p")
    stub = stub_request(:delete, "https://dav.example.org/cal/evt-9.ics").to_return(status: 204)

    CaldavSyncAppointmentJob.perform_now(action: "delete", provider_id: @provider.id, caldav_event_id: "evt-9")
    assert_requested stub
  end
end
