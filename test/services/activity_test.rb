require "test_helper"

# The activity log: one row per significant thing the system did, for the
# admin Activity page. Recording can be silenced (imports) and carries the
# actor set for the current request.
class ActivityTest < ActiveSupport::TestCase
  test "record writes an event with the current actor" do
    Current.actor = "Grey (admin)"
    appointment = appointments(:upcoming)
    event = Activity.record(:appointment_booked, summary: "Haircut for Jx with Zane", appointment: appointment,
                                                 details: "Status Booked")
    assert event.persisted?
    assert_equal "appointment_booked", event.kind
    assert_equal "Grey (admin)", event.actor
    assert_equal appointment.id, event.appointment_id
    assert_equal appointment.id_users_customer, event.customer_id
    assert_equal "Status Booked", event.details
  ensure
    Current.reset
  end

  test "actor defaults to system when none is set" do
    Current.reset
    event = Activity.record(:message_sent, summary: "Reminder to customer")
    assert_equal Activity::SYSTEM, event.actor
    assert_nil event.appointment_id
  end

  test "silenced blocks writes inside and restores afterwards" do
    assert_no_difference "ActivityEvent.count" do
      Activity.silenced { Activity.record(:appointment_booked, summary: "quiet") }
    end
    assert_difference "ActivityEvent.count", 1 do
      Activity.record(:appointment_booked, summary: "loud")
    end
  end

  test "a failing builder never breaks the action being logged" do
    assert_nothing_raised do
      assert_nil Activity.message_event(Object.new)
      assert_nil Activity.appointment_event(Webhooks::APPOINTMENT_SAVE, Object.new)
    end
    assert_equal 0, ActivityEvent.count
  end

  test "unknown kinds are rejected" do
    assert_raises(ArgumentError) { Activity.record(:made_up, summary: "x") }
  end
end
