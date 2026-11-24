require "test_helper"

# Messages, waiting list signups and the launch-day reminder marking leave
# lines in the activity log.
class ActivityMessagesTest < ActiveSupport::TestCase
  setup do
    Current.reset
    @notification = Notification.create!(title: "Reminder 24h", event: "coming_up", lead_mode: "before", lead_days: 1,
                                         lead_hours: 0, audiences: %w[customer], channels: %w[email], short_text: "See you")
  end

  def outgoing(status: "queued")
    Message.create!(direction: "outgoing", channel: "email", audience: "customer", to_address: "c@example.org",
                    customer: users(:jx), appointment: appointments(:upcoming), notification: @notification,
                    subject: "See you", body: "See you tomorrow", status: status)
  end

  test "an outgoing message is recorded when it is sent, not when queued" do
    message = nil
    assert_no_difference "ActivityEvent.count" do
      message = outgoing
    end
    assert_difference "ActivityEvent.count", 1 do
      message.update!(status: "sent")
    end
    event = ActivityEvent.newest_first.first
    assert_equal "message_sent", event.kind
    assert_equal Activity::SYSTEM, event.actor
    assert_equal message.id, event.message_id
    assert_equal users(:jx).id, event.customer_id
    assert_equal appointments(:upcoming).id, event.appointment_id
    assert_match "Reminder 24h", event.summary
    assert_match "c@example.org", event.summary
  end

  test "a failed message is recorded with its error" do
    message = outgoing
    message.update!(status: "failed", error: "SMTP 550 mailbox unavailable")
    event = ActivityEvent.newest_first.first
    assert_equal "message_failed", event.kind
    assert_match "SMTP 550", event.details
  end

  test "an incoming message is recorded on arrival" do
    Message.create!(direction: "incoming", channel: "smsgateway", from_address: "+447700900999",
                    customer: users(:jx), body: "Running late", status: "received")
    event = ActivityEvent.newest_first.first
    assert_equal "message_received", event.kind
    assert_match "+447700900999", event.summary
    assert_equal users(:jx).id, event.customer_id
  end

  test "a waiting list signup is recorded" do
    WaitlistEntry.create!(name: "Pat", email: "pat@example.org", service: services(:haircut), provider: users(:zane))
    event = ActivityEvent.newest_first.first
    assert_equal "waitlist_signup", event.kind
    assert_match "Pat", event.summary
    assert_match "Zane", event.summary
  end

  test "marking due reminders as sent is recorded with the count" do
    start = Time.new(2026, 8, 4, 9, 0, 0)
    Appointment.create!(provider: users(:zane), customer: users(:jx), service: services(:haircut),
                        start_datetime: start, end_datetime: start + 30.minutes, status: "Booked")
    now = Time.find_zone!(users(:zane).effective_timezone).parse("2026-08-03 10:00")
    assert_no_difference "ActivityEvent.count" do
      Notifications.mark_due_reminders_sent(now, dry_run: true)
    end
    count = Notifications.mark_due_reminders_sent(now)
    event = ActivityEvent.newest_first.first
    assert_equal "reminders_marked", event.kind
    assert_match count.to_s, event.summary
  end
end
