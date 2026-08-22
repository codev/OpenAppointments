# The two customer-facing windows in Business Settings, stored as minutes:
# book_advance_timeout (how close to the start a slot can be booked) and
# late_cancellation_timeout (how close a reschedule/cancel still counts as in
# time). The late window cannot exceed the booking window.
module BookingWindows
  module_function

  def minutes(name)
    value = Setting.get(name, "0").to_s
    value.match?(/\A-?\d+\z/) ? [ value.to_i, 0 ].max : 0
  end

  def late_minutes = minutes("late_cancellation_timeout")

  def late?(appointment, now = Time.now)
    appointment.start_datetime - now < late_minutes * 60
  end

  def hours_and_minutes(total) = total.divmod(60)

  def late_notice(helpers)
    hours, mins = hours_and_minutes(late_minutes)
    helpers.lang("late_cancel_notice").sub("{$hours}", hours.to_s).sub("{$minutes}", mins.to_s)
  end
end
