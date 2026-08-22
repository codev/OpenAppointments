# A repeating appointment: an IceCube schedule plus the booking details. Every
# occurrence is a real Appointment row (series_id, occurrence_at) so the rest of
# the app treats them as ordinary bookings. Dates that clash are skipped and
# recorded; dates the user deletes are recorded so they are never recreated.
class AppointmentSeries < ApplicationRecord
  FREQUENCIES = %w[daily weekly monthly].freeze
  SKIP_REASONS = %w[busy not_working blocked].freeze

  belongs_to :provider, class_name: "User", foreign_key: :id_users_provider
  belongs_to :customer, class_name: "User", foreign_key: :id_users_customer
  belongs_to :service, foreign_key: :id_services
  has_many :appointments, foreign_key: :series_id, inverse_of: :series, dependent: :nullify

  validates :schedule, :starts_on, :start_time, :duration, presence: true
  validates :start_time, format: { with: /\A\d{2}:\d{2}\z/ }
  validates :duration, numericality: { greater_than: 0 }

  scope :for_provider, ->(provider_id) { where(id_users_provider: provider_id) }
  scope :open, -> { where("ends_on IS NULL OR ends_on >= ?", Date.current) }

  # Start a series from a just-saved first appointment and book the rest.
  def self.start_from(appointment, repeat, created_by: nil)
    starts_on = appointment.start_datetime.to_date
    series = create!(
      id_users_provider: appointment.id_users_provider, id_users_customer: appointment.id_users_customer,
      id_services: appointment.id_services, ice_schedule: schedule_from(repeat, starts_on),
      starts_on: starts_on, ends_on: repeat["ends"] == "on" ? Date.parse(repeat["ends_on"].to_s) : nil,
      start_time: appointment.start_datetime.strftime("%H:%M"), duration: appointment.duration_minutes,
      notes: appointment.notes, location: appointment.location, status: appointment.status,
      color: appointment.color, created_by: created_by
    )
    appointment.update!(series_id: series.id, occurrence_at: starts_on)
    series.materialise(now: starts_on).merge(series: series)
  end

  # A deleted occurrence is never recreated.
  def forget(date)
    return unless date

    update!(removed: (removed_list | [ date.to_s ]).to_json)
  end

  # Build the stored schedule from the repeat fields: the recurring_select rule hash
  # (JSON string or hash) plus ends: never|on|after with ends_on / count. The
  # schedule is anchored at anchor (default the series start). A weekly or
  # monthly rule with no day picked (the dialog saved unedited) keeps the days of
  # previous (the current rule) when it is the same type, else starts_on's day.
  def self.schedule_from(repeat, starts_on, anchor: starts_on, previous: nil)
    rule = RecurringSelect.dirty_hash_to_rule(repeat["rule"])
    raise ArgumentError, "Unknown repeat pattern." unless rule

    same = previous.class == rule.class ? previous : nil
    if rule.is_a?(IceCube::WeeklyRule) && rule.validations[:day].blank?
      days = same ? same.validations[:day].map(&:day) : [ starts_on.wday ]
      rule.day(*days)
    end
    if rule.is_a?(IceCube::MonthlyRule) && rule.validations[:day_of_month].blank?
      days = same ? same.validations[:day_of_month].map(&:day) : [ starts_on.day ]
      rule.day_of_month(*days)
    end

    # A round-tripped rule carries its old count/until; the ends fields decide.
    rule.until(nil)
    rule.count(nil)
    case repeat["ends"]
    when "on" then rule.until(Date.parse(repeat["ends_on"].to_s).end_of_day)
    when "after" then rule.count([ repeat["count"].to_i, 1 ].max)
    end
    schedule = IceCube::Schedule.new(anchor.to_time)
    schedule.add_recurrence_rule(rule)
    schedule
  end

  # The first rule's hash, for the dropdown.
  def rule_hash
    ice_schedule.recurrence_rules.first&.to_hash
  end

  def ice_schedule
    @ice_schedule ||= IceCube::Schedule.from_hash(JSON.parse(schedule))
  end

  def ice_schedule=(value)
    @ice_schedule = value
    self.schedule = value.to_hash.to_json
  end

  # Human text, in the locale if IceCube has it.
  def description
    ice_schedule.to_s
  rescue StandardError
    I18n.with_locale(:en) { ice_schedule.to_s }
  end

  def skipped_list = JSON.parse(skipped.presence || "[]")
  def removed_list = JSON.parse(removed.presence || "[]")

  # Booking window end: the Future Booking Limit, capped by the series end.
  def self.horizon(now = Date.current)
    limit = Setting.get("future_booking_limit", "90").to_i
    now + [ limit, 0 ].max.days
  end

  def horizon(now = Date.current)
    h = self.class.horizon(now)
    ends_on && ends_on < h ? ends_on : h
  end

  # Occurrence dates between from and to, minus removed ones.
  def dates_between(from, to)
    return [] if to < from

    ice_schedule.occurrences_between(from.to_time.beginning_of_day, to.to_time.end_of_day)
                .map(&:to_date).uniq - removed_list.map { |d| Date.parse(d) }
  end

  def future_dates(now = Date.current)
    dates_between([ now, starts_on ].max, horizon(now))
  end

  def starts_at(date)
    hour, minute = start_time.split(":").map(&:to_i)
    Time.new(date.year, date.month, date.day, hour, minute, 0)
  end

  # Create the missing occurrences up to the horizon. Clashing dates are skipped
  # and recorded. Returns {created: [dates], rows: [appointments], skipped: [{date, reason}]}.
  def materialise(now: Date.current)
    existing = appointments.where.not(occurrence_at: nil).pluck(:occurrence_at)
    already_skipped = skipped_list.to_h { |entry| [ entry["date"], entry["reason"] ] }
    created = []
    rows = []
    newly_skipped = []

    (future_dates(now) - existing).each do |date|
      reason = clash_reason(date)
      if reason
        newly_skipped << { "date" => date.to_s, "reason" => reason } unless already_skipped[date.to_s] == reason
        next
      end

      rows << appointments.create!(
        id_users_provider: id_users_provider, id_users_customer: id_users_customer, id_services: id_services,
        start_datetime: starts_at(date), end_datetime: starts_at(date) + duration * 60,
        notes: notes, location: location.to_s, appointment_status: AppointmentStatus.of("booked"),
        color: color.presence || "#7cbae8", book_datetime: Time.now, occurrence_at: date
      )
      created << date
    end

    # Drop stale skips for dates now booked or outside the window; keep the rest.
    remaining = skipped_list.select { |entry| Date.parse(entry["date"]) >= now && !created.include?(Date.parse(entry["date"])) }
    remaining.reject! { |entry| newly_skipped.any? { |n| n["date"] == entry["date"] } }
    update!(skipped: (remaining + newly_skipped).sort_by { |entry| entry["date"] }.to_json)

    { created: created, rows: rows, skipped: newly_skipped }
  end

  # Sync, webhook and (optionally) notify for rows a series edit created or
  # marked rescheduled/cancelled. The customer gets one notification, on the
  # first new row (its email carries the repeat pattern and next date), or one
  # cancellation on the first removed row when nothing was created.
  def announce(created: [], removed: [], notify: false, reason: nil)
    removed.each do |appointment|
      Synchronization.appointment_deleted(appointment, appointment.provider)
      Webhooks.trigger(Webhooks::APPOINTMENT_DELETE, appointment)
    end
    created.each do |appointment|
      Synchronization.appointment_saved(appointment, appointment.service, appointment.provider, appointment.customer, nil)
      Webhooks.trigger(Webhooks::APPOINTMENT_SAVE, appointment)
    end
    return unless notify

    if (first = created.first)
      Notifications.appointment_saved(first, first.service, first.provider, first.customer, nil, manage_mode: true)
    elsif (first = removed.first)
      Notifications.appointment_deleted(first, first.service, first.provider, first.customer, nil, reason: reason)
    end
  end

  # Why the occurrence cannot be booked on this date, or nil.
  def clash_reason(date)
    slot_start = starts_at(date)
    slot_end = slot_start + duration * 60
    return "blocked" if BlockedPeriod.for_period(date.to_s, date.to_s).exists?
    return "busy" if Appointment.provider_conflict?(id_users_provider, slot_start, slot_end)

    periods = Availability::Engine.new.available_periods(date.to_s, provider)
    fits = periods.any? do |period|
      period_start = Time.new(date.year, date.month, date.day, *period["start"].split(":").map(&:to_i))
      period_end = Time.new(date.year, date.month, date.day, *period["end"].split(":").map(&:to_i))
      period_start <= slot_start && slot_end <= period_end
    end
    fits ? nil : "not_working"
  end

  # Cancel future occurrences from a date on and end the series the day before.
  def cancel_from(date, reason: nil)
    to_cancel = appointments.active.where("occurrence_at >= ?", date).to_a
    to_cancel.each { |appointment| appointment.cancel!(reason: reason) }
    update!(ends_on: date - 1, skipped: skipped_list.reject { |e| Date.parse(e["date"]) >= date }.to_json)
    to_cancel
  end

  # Replace the pattern after today: future occurrences still on the old
  # pattern are marked Rescheduled (kept, slot freed) and the new pattern is
  # booked; earlier ones and occurrences a customer moved are left alone.
  # Returns materialise's result plus rescheduled: [appointments].
  def reschedule!(repeat, now: Date.current)
    self.ice_schedule = self.class.schedule_from(repeat, starts_on, anchor: [ starts_on, now ].max,
                                                 previous: ice_schedule.recurrence_rules.first)
    self.ends_on = repeat["ends"] == "on" ? Date.parse(repeat["ends_on"].to_s) : nil
    rescheduled = appointments.active.where("occurrence_at > ?", now).select { |a| a.start_datetime == starts_at(a.occurrence_at) }
    transaction do
      rescheduled.each do |appointment|
        appointment.update!(appointment_status: AppointmentStatus.of("rescheduled"), occurrence_at: nil)
      end
      update!(skipped: "[]")
    end
    materialise(now: now).merge(rescheduled: rescheduled)
  end
end
