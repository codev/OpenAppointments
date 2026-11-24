require "test_helper"

# Activity page helpers: one badge colour per kind, and the summary and details
# with their template's own words set apart from the names and times.
class ActivityHelperTest < ActionView::TestCase
  test "every kind has its own badge colour and booked is green" do
    classes = Activity::KINDS.map { |kind| activity_badge_class(kind) }
    assert_equal classes.uniq.size, classes.size, "kinds share a badge colour: #{classes.inspect}"
    assert_equal "text-bg-success", activity_badge_class("appointment_booked")
    assert_equal "text-bg-secondary", activity_badge_class("unknown")
  end

  test "the summary's joining words are italic and the values are escaped" do
    event = ActivityEvent.new(kind: "appointment_booked", summary: "Trim Cut for J <X> with Zane, Mon 20 Jul 2026 10:00-10:30")
    html = activity_summary_html(event)
    assert_equal 'Trim Cut <i class="activity-joiner">for</i> J &lt;X&gt; <i class="activity-joiner">with</i> Zane, Mon 20 Jul 2026 10:00-10:30', html
    assert html.html_safe?
  end

  test "a summary that does not match its template stays plain" do
    event = ActivityEvent.new(kind: "appointment_booked", summary: "older wording <b>here</b>")
    assert_equal "older wording &lt;b&gt;here&lt;/b&gt;", activity_summary_html(event)
    assert_equal "3", activity_summary_html(ActivityEvent.new(kind: "reminders_marked", summary: "3"))
  end

  test "the status and reason details are styled, singly or together" do
    event = ActivityEvent.new(kind: "appointment_cancelled", details: "Status Cancelled. Reason: Feeling unwell. Will rebook")
    assert_equal '<i class="activity-joiner">Status</i> Cancelled. <i class="activity-joiner">Reason:</i> Feeling unwell. Will rebook',
                 activity_details_html(event)
    assert_equal '<i class="activity-joiner">Status</i> Booked',
                 activity_details_html(ActivityEvent.new(kind: "appointment_booked", details: "Status Booked"))
    assert_equal "SMTP timed out", activity_details_html(ActivityEvent.new(kind: "message_failed", details: "SMTP timed out"))
  end
end
