# The two customer-facing windows in Business Settings, stored as minutes:
# book_advance_timeout (how close to the start a slot can be booked) and
# late_cancellation_timeout (how close a reschedule/cancel still counts as in
# time).
module BookingWindows
  module_function

  def minutes(name)
    value = Setting.get(name, "0").to_s
    value.match?(/\A-?\d+\z/) ? [ value.to_i, 0 ].max : 0
  end

  def late_minutes = minutes("late_cancellation_timeout")

  # The appointment start as an absolute time: start_datetime is stored in the
  # provider's local time.
  def starts_at(appointment)
    zone = Time.find_zone!(appointment.provider&.effective_timezone || Time.zone.name)
    zone.parse(appointment.start_datetime.strftime("%Y-%m-%d %H:%M:%S"))
  end

  def past?(appointment, now = Time.now) = starts_at(appointment) < now

  # Now on the default zone's clock as a plain Time, the form stored times use.
  def wall_clock_now
    now = Time.now.in_time_zone(Setting.get("default_timezone", "UTC"))
    Time.new(now.year, now.month, now.day, now.hour, now.min, now.sec)
  end

  def late?(appointment, now = Time.now)
    starts_at(appointment) - now < late_minutes * 60
  end

  def hours_and_minutes(total) = total.divmod(60)

  def late_notice(helpers)
    hours, mins = hours_and_minutes(late_minutes)
    helpers.lang("late_cancel_notice").sub("{$hours}", hours.to_s).sub("{$minutes}", mins.to_s)
  end
end
