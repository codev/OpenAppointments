# The two customer-facing windows in Business Settings, stored as minutes:
# book_advance_timeout (how close to the start a slot can be booked) and
# late_cancellation_timeout (how close a reschedule/cancel still counts as in
# time).
module BookingWindows
  RELEASE_TIME_FORMAT = /\A([01]\d|2[0-3]):[0-5]\d\z/

  module_function

  def minutes(name)
    value = Setting.get(name, "0").to_s
    value.match?(/\A-?\d+\z/) ? [ value.to_i, 0 ].max : 0
  end

  def late_minutes = minutes("late_cancellation_timeout")

  # The last date public booking offers: today plus the Future Booking Limit
  # in days, on the business clock (default_timezone). The newest day opens at
  # the release time; before it the window ends a day earlier.
  def last_bookable_date(now = Time.now)
    local = now.in_time_zone(Setting.get("default_timezone", "UTC"))
    days = future_booking_limit_days
    days -= 1 if local.strftime("%H:%M") < release_time
    local.to_date + days
  end

  def future_booking_limit_days
    limit = Setting.get("future_booking_limit", "90").to_s
    limit.match?(/\A-?\d+\z/) ? [ limit.to_i, 0 ].max : 90
  end

  # "HH:MM", default 00:00 (the newest day opens at midnight).
  def release_time
    value = Setting.get("booking_release_time", "00:00").to_s
    value.match?(RELEASE_TIME_FORMAT) ? value : "00:00"
  end

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
