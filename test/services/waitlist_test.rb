require "test_helper"

# The waiting list: a freed slot tells the matching signups one by one, longest
# waiting first and a stagger apart; the daily scan tells signups whose service
# has enough free hours in the booking window, once a day.
class WaitlistTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActiveSupport::Testing::TimeHelpers

  NO_HOURS = { monday: nil, tuesday: nil, wednesday: nil, thursday: nil, friday: nil, saturday: nil, sunday: nil }.to_json

  setup do
    Setting.set("waitlist_enabled", "1")
    Setting.set("waitlist_stagger_seconds", "60")
    @provider = users(:zane)
    @service = services(:haircut)
    @slot_freed = Notification.create!(
      title: "Slot Freed", event: "waitlist_slot_freed", channels: %w[email],
      short_text: "Free: {{Service Name}} on {{Appointment Date}} at {{Appointment Time}}",
      long_text: "Hi {{Customer First Name}}, {{Provider Name}} is free. Book: {{Booking Link}} Leave: {{Unsubscribe Link}}"
    )
    @daily = Notification.create!(
      title: "Daily", event: "waitlist_daily", channels: %w[email],
      short_text: "Available: {{Service Name}}", long_text: "Book: {{Booking Link}} Leave: {{Unsubscribe Link}}"
    )
  end

  # Ten days before a Monday in Zane's plan (see the availability engine tests).
  def booking_time = Time.new(2026, 7, 10, 12, 0, 0)
  def slot_start = Time.new(2026, 7, 20, 11, 0, 0)

  def sign_up(email, created_at: Time.current, **attrs)
    WaitlistEntry.create!({ name: "Wait #{email}", email: "#{email}@example.org", service: @service, created_at: created_at }.merge(attrs))
  end

  def freed_appointment(status = "Cancelled")
    Appointment.create!(provider: @provider, customer: users(:jx), service: @service, status: status,
                        start_datetime: slot_start, end_datetime: slot_start + 30.minutes)
  end

  def notice_jobs
    enqueued_jobs.select { |job| job["job_class"] == "WaitlistNoticeJob" }
  end

  def waitlist_messages = Message.where(audience: "waitlist").order(:id)

  test "the events are valid with their own triggers" do
    assert_equal [ @slot_freed ], Notification.for_trigger(:waitlist_slot_freed).to_a
    assert_equal [ @daily ], Notification.for_trigger(:waitlist_daily).to_a
    assert_includes Messaging::Template::TOKENS, "Booking Link"
    assert_includes Messaging::Template::TOKENS, "Unsubscribe Link"
  end

  test "a freed slot queues one notice per matching signup, longest waiting first, a stagger apart" do
    travel_to(booking_time) do
      early = sign_up("early", created_at: 2.hours.ago)
      late = sign_up("late", created_at: 1.hour.ago)
      sign_up("longer", service: services(:group_session))
      Waitlist.slot_freed(freed_appointment)

      jobs = notice_jobs
      assert_equal [ early.id, late.id ], jobs.map { |job| job["arguments"].first }
      assert_nil jobs[0][:at]
      assert_in_delta 60, jobs[1][:at] - Time.current.to_f, 1
    end
  end

  test "the notice renders the templates with the slot, the booking link and the leave link, and counts it" do
    travel_to(booking_time) do
      entry = sign_up("early")
      Waitlist.slot_freed(freed_appointment)
      perform_enqueued_jobs(only: WaitlistNoticeJob)

      message = waitlist_messages.sole
      assert_equal [ "email", "early@example.org", @slot_freed.id ], [ message.channel, message.to_address, message.notification_id ]
      assert_match(/\AFree: Trim Cut on .*2026 at 11:00/, message.subject)
      assert_match "Hi Wait, Zane is free.", message.body
      assert_match "/booking?service=abcd-efgh&provider=cdef-ghjk&date=2026-07-20&time=11:00&step=time", message.body
      assert_match "/booking/waitlist/leave/#{entry.unsubscribe_token}", message.body
      assert_equal 1, entry.reload.notices_sent
    end
  end

  test "a notice is skipped when the slot was taken, the signup expired or left, or the cap is reached" do
    travel_to(booking_time) do
      taken = sign_up("taken")
      Waitlist.slot_freed(freed_appointment)
      booked = freed_appointment("Booked")
      perform_enqueued_jobs(only: WaitlistNoticeJob)
      assert_equal 0, waitlist_messages.count
      assert_equal 0, taken.reload.notices_sent
      taken.destroy!

      expired = sign_up("expired")
      left = sign_up("left")
      capped = sign_up("capped", notices_sent: 6)
      booked.destroy!
      Waitlist.slot_freed(freed_appointment)
      assert_equal 3, notice_jobs.size
      expired.update!(expires_at: 1.minute.ago)
      left.destroy!
      perform_enqueued_jobs(only: WaitlistNoticeJob)
      assert_equal [ "capped@example.org" ], waitlist_messages.map(&:to_address)
      assert_equal 7, capped.reload.notices_sent
      assert_not capped.notices_left?
    end
  end

  test "the daily scan tells signups whose service has enough free hours, once a day" do
    travel_to(booking_time) do
      Setting.set("waitlist_min_slots", "3")
      entry = sign_up("daily")
      Waitlist.scan_daily
      perform_enqueued_jobs(only: WaitlistNoticeJob)
      message = waitlist_messages.sole
      assert_equal "Available: Trim Cut", message.subject
      assert_match "/booking?service=abcd-efgh", message.body
      assert_in_delta Time.current, entry.reload.last_digest_at, 5
      assert_equal 0, entry.notices_sent

      Waitlist.scan_daily
      assert_equal 0, notice_jobs.size

      travel 1.day
      @provider.settings.update!(working_plan: NO_HOURS)
      Waitlist.scan_daily
      assert_equal 0, notice_jobs.size
    end
  end

  test "a cancelled or deleted appointment frees its slot for the list" do
    travel_to(booking_time) do
      sign_up("cancel")
      appointment = freed_appointment("Booked")
      Notifications.appointment_saved(appointment.tap { |a| a.update!(status: "Cancelled") }, @service, @provider, users(:jx),
                                      manage_mode: true, previous_status_id: AppointmentStatus.find_by!(name: "Booked").id)
      assert_equal 1, notice_jobs.size
      clear_enqueued_jobs
      Notifications.appointment_deleted(appointment, @service, @provider, users(:jx))
      assert_equal 1, notice_jobs.size
    end
  end

  test "nothing is queued while the waitlist or messaging is off" do
    travel_to(booking_time) do
      sign_up("off")
      Setting.set("waitlist_enabled", "0")
      Waitlist.slot_freed(freed_appointment)
      Waitlist.scan_daily
      Setting.set("waitlist_enabled", "1")
      Setting.set("messages_enabled", "0")
      Waitlist.slot_freed(freed_appointment)
      Waitlist.scan_daily
      assert_equal 0, notice_jobs.size
    end
  end
end
