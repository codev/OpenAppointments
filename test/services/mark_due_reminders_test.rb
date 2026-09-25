require "test_helper"
require "rake"

# Launch day: appointments whose reminder is already due (10to8 sent it, or
# debug mode held it back) are marked reminded, so switching debug off does
# not send a second reminder. Later reminders still go.
class MarkDueRemindersTest < ActiveSupport::TestCase
  setup do
    @notification = Notification.create!(title: "Reminder", event: "coming_up", lead_mode: "before", lead_days: 1,
                                         lead_hours: 0, audiences: %w[customer], channels: %w[email], short_text: "See you")
    @clock = Time.find_zone!(users(:zane).effective_timezone)
    @now = @clock.parse("2026-08-03 10:00")
    book = lambda do |start|
      Appointment.create!(provider: users(:zane), customer: users(:jx), service: services(:haircut),
                          start_datetime: start, end_datetime: start + 30.minutes, status: "Booked")
    end
    @due = book.call(Time.new(2026, 8, 4, 9, 0, 0))    # reminder due since 3 Aug 09:00
    @later = book.call(Time.new(2026, 8, 6, 9, 0, 0))  # reminder due 5 Aug
  end

  test "due reminders are marked sent, later ones are left for the scan" do
    assert_equal 1, Notifications.mark_due_reminders_sent(@now)
    assert NotificationDispatch.exists?(notification: @notification, appointment: @due)
    assert_not NotificationDispatch.exists?(appointment: @later)

    Notifications.scan_coming_up(@now)
    assert_equal 0, Message.count, "the marked reminder is not sent"
    Notifications.scan_coming_up(@clock.parse("2026-08-05 10:00"))
    assert_equal [ @later.id ], Message.pluck(:appointment_id)
    assert_equal 0, Notifications.mark_due_reminders_sent(@now), "a second run marks nothing new"
  end

  test "a dry run counts without marking" do
    assert_equal 1, Notifications.mark_due_reminders_sent(@now, dry_run: true)
    assert_equal 0, NotificationDispatch.count
  end

  test "the rake task prints the count and honours DRY_RUN" do
    Rails.application.load_tasks unless Rake::Task.task_defined?("notifications:mark_due_reminders_sent")
    travel_to @now do
      ENV["DRY_RUN"] = "1"
      assert_output(/1 reminder\(s\) would be marked sent/) { Rake::Task["notifications:mark_due_reminders_sent"].execute }
      ENV.delete("DRY_RUN")
      assert_output(/1 reminder\(s\) marked sent/) { Rake::Task["notifications:mark_due_reminders_sent"].execute }
    end
    assert_equal 1, NotificationDispatch.count
  ensure
    ENV.delete("DRY_RUN")
  end
end
