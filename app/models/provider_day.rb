# One provider's day on the appointments page: the working hours (working plan
# or exception), its appointments, unavailabilities, blocked periods and the
# free gaps between them, as entries in time order.
class ProviderDay
  MIN_FREE_MINUTES = 15

  Entry = Struct.new(:kind, :start, :end, :title, :color, :record, keyword_init: true)

  attr_reader :provider, :date

  def initialize(provider, date, appointments:, unavailabilities:, blocked_periods:)
    @provider = provider
    @date = date
    @appointments = appointments
    @unavailabilities = unavailabilities
    @blocked_periods = blocked_periods
  end

  def day_plan
    @day_plan ||= begin
      exceptions = WorkingPlanException.expanded_for(provider.id)
      key = date.strftime("%Y-%m-%d")
      exceptions.key?(key) ? exceptions[key] : (provider.working_plan || {})[date.strftime("%A").downcase]
    end
  end

  def working? = day_plan.present?

  def entries
    return [] unless working?

    (appointment_entries + unavailability_entries + blocked_entries + break_entries + free_entries)
      .sort_by { |entry| [ entry.start, entry.end ] }
  end

  private

  def appointment_entries
    @appointments.map do |appointment|
      detail = appointment.service&.name.to_s
      name = appointment.customer&.name
      Entry.new(kind: appointment.frees_slot? ? "freed" : "appointment", start: appointment.start_datetime,
                end: appointment.end_datetime, title: name.present? ? "#{name} - #{detail}" : detail,
                color: appointment.color, record: appointment)
    end
  end

  def unavailability_entries
    @unavailabilities.map do |unavailability|
      Entry.new(kind: "unavailability", start: unavailability.start_datetime, end: unavailability.end_datetime,
                title: unavailability.notes.presence || I18n.t("ea.unavailability"), record: unavailability)
    end
  end

  def blocked_entries
    @blocked_periods.map do |period|
      Entry.new(kind: "blocked", start: [ period.start_datetime, wall_time("00:00") ].max,
                end: [ period.end_datetime, wall_time("23:59") ].min, title: period.name, record: period)
    end
  end

  def break_entries
    Array(day_plan["breaks"]).map do |period|
      Entry.new(kind: "break", start: wall_time(period["start"]), end: wall_time(period["end"]), title: I18n.t("ea.break"))
    end
  end

  # Working time left after breaks and busy events, as the booking engine sees it.
  def free_entries
    Availability::Engine.new.available_periods(date.strftime("%Y-%m-%d"), provider).filter_map do |period|
      start_time = wall_time(period["start"])
      end_time = wall_time(period["end"])
      next if ((end_time - start_time) / 60) < MIN_FREE_MINUTES

      Entry.new(kind: "free", start: start_time, end: end_time, title: I18n.t("ea.free_for_appointments"))
    end
  end

  # Stored datetimes are plain Time values in the process zone (no zone-aware
  # attributes); the day's own times are built the same way so they compare.
  def wall_time(hhmm)
    hour, minute = hhmm.split(":").map(&:to_i)
    Time.new(date.year, date.month, date.day, hour, minute, 0)
  end
end
