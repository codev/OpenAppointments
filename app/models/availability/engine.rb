module Availability
  # Port of EA's Availability library, quirks preserved deliberately:
  # - a date counts as fully blocked only when MORE THAN ONE blocked period covers it
  # - single-attendant periods only exist when the day plan has a "breaks" key
  # - future_booking_limit passes only strictly-greater thresholds (boundary day = no hours)
  # - available hours are string-sorted
  # - period splits appended mid-iteration are visited again (PHP by-reference foreach);
  #   the split branches are idempotent so revisits are harmless but order is preserved
  # All times are provider-local wall-clock; `now` is injectable for tests.
  class Engine
    def initialize(now: nil)
      @now = now
      @exceptions = {}
    end

    # BookingWindow asks for every day of a range: load each table once instead
    # of once per date. Without a preload every call queries for its date.
    def preload(providers, from, to)
      @events = providers.to_h do |provider|
        [ provider.id, Appointment.active.where(id_users_provider: provider.id)
                                  .where("DATE(start_datetime) <= ? AND DATE(end_datetime) >= ?", to, from).to_a ]
      end
      @blocked = BlockedPeriod.for_period(from, to).to_a
    end

    def available_hours(date, service, provider, exclude_appointment_id: nil)
      return [] if entire_date_blocked?(date)

      hours =
        if service.attendants_number.to_i > 1
          consider_multiple_attendants(date, service, provider, exclude_appointment_id)
        else
          periods = available_periods(date, provider, exclude_appointment_id)
          generate_available_hours(date, service, periods)
        end

      hours = consider_book_advance_timeout(date, hours, provider)
      consider_future_booking_limit(date, hours)
    end

    # Free {start:, end:} "HH:MM" pairs for the date, after breaks and events.
    def available_periods(date, provider, exclude_appointment_id = nil)
      raise ArgumentError, "Invalid date format provided." unless date.match?(/\A\d{4}-\d{2}-\d{2}\z/)

      working_plan = provider.working_plan || {}
      exceptions = exceptions_for(provider.id)

      events = events_for(date, provider, exclude_appointment_id) + blocked_for(date)

      day_plan = exceptions.key?(date) ? exceptions[date] : working_plan[weekday(date)]
      return [] unless day_plan

      periods = {}
      next_key = 0

      # EA only initializes periods when the day plan carries a breaks key.
      if day_plan.key?("breaks")
        periods[next_key] = { "start" => day_plan["start"], "end" => day_plan["end"] }
        next_key += 1

        day_start = wall_time(date, day_plan["start"])
        day_end = wall_time(date, day_plan["end"])

        day_plan["breaks"].each do |brk|
          break_start = wall_time(date, brk["start"])
          break_end = wall_time(date, brk["end"])
          break_start = day_start if break_start < day_start
          break_end = day_end if break_end > day_end
          next if break_start >= break_end

          periods.keys.each do |key|
            period = periods[key] or next
            period_start = wall_time(date, period["start"])
            period_end = wall_time(date, period["end"])

            remove_current = false

            if break_start > period_start && break_start < period_end && break_end > period_start
              periods[next_key] = { "start" => hhmm(period_start), "end" => hhmm(break_start) }
              next_key += 1
              remove_current = true
            end

            if break_start < period_end && break_end > period_start && break_end < period_end
              periods[next_key] = { "start" => hhmm(break_end), "end" => hhmm(period_end) }
              next_key += 1
              remove_current = true
            end

            remove_current = true if break_start == period_start && break_end == period_end

            periods.delete(key) if remove_current
          end
        end
      end

      events.each do |event|
        periods.keys.each do |key|
          period = periods[key] or next
          event_start = event.start_datetime
          event_end = event.end_datetime
          next if event_start >= event_end

          period_start = wall_time(date, period["start"])
          period_end = wall_time(date, period["end"])

          if event_start <= period_start && event_end <= period_end && event_end <= period_start
            # Event before the period: nothing to change.
            next
          elsif event_start <= period_start && event_end <= period_end && event_end >= period_start
            # Event overlaps the period start.
            period["start"] = hhmm(event_end)
          elsif event_start >= period_start && event_end < period_end
            # Event inside the period: split in two.
            periods.delete(key)
            periods[next_key] = { "start" => hhmm(period_start), "end" => hhmm(event_start) }
            next_key += 1
            periods[next_key] = { "start" => hhmm(event_end), "end" => hhmm(period_end) }
            next_key += 1
          elsif event_start == period_start && event_end == period_end
            periods.delete(key)
          elsif event_start >= period_start && event_end >= period_start && event_start <= period_end
            # Event overlaps the period end.
            period["end"] = hhmm(event_start)
          elsif event_start >= period_start && event_end >= period_end && event_start >= period_end
            # Event after the period: nothing to change.
            next
          elsif event_start <= period_start && event_end >= period_end && event_start <= period_end
            # Event swallows the period.
            periods.delete(key)
          end
        end
      end

      periods.values
    end

    def generate_available_hours(date, service, empty_periods)
      interval = service.slot_interval.to_i.positive? ? service.slot_interval.to_i : 15
      duration = service.duration.to_i

      hours = []
      empty_periods.each do |period|
        current = wall_time(date, period["start"])
        period_end = wall_time(date, period["end"])

        while ((period_end - current) / 60).to_i >= duration && current <= period_end
          hours << hhmm(current)
          current += interval * 60
        end
      end

      hours
    end

    private

    def consider_multiple_attendants(date, service, provider, exclude_appointment_id)
      unavailabilities = events_for(date, provider, exclude_appointment_id).select(&:is_unavailability)
      blocked = blocked_for(date)

      exceptions = exceptions_for(provider.id)
      working_plan = provider.working_plan || {}
      day_plan = exceptions.key?(date) ? exceptions[date] : working_plan[weekday(date)]
      return [] unless day_plan

      periods = [ { start: wall_time(date, day_plan["start"]), end: wall_time(date, day_plan["end"]) } ]
      periods = remove_breaks(date, periods, day_plan["breaks"] || [])
      periods = remove_events(periods, unavailabilities)
      periods = remove_events(periods, blocked)

      interval = service.slot_interval.to_i.positive? ? service.slot_interval.to_i : 15
      duration = service.duration.to_i

      hours = []
      periods.each do |period|
        slot_start = period[:start]
        slot_end = slot_start + duration * 60

        while slot_end <= period[:end]
          if Appointment.other_service_attendants(slot_start, slot_end, service.id, provider.id,
                                                  exclude_appointment_id).positive?
            slot_start += interval * 60
            slot_end += interval * 60
            next
          end

          reserved = Appointment.attendants_for_period(slot_start, slot_end, service.id, provider.id,
                                                       exclude_appointment_id)
          hours << hhmm(slot_start) if reserved < service.attendants_number.to_i

          slot_start += interval * 60
          slot_end += interval * 60
        end
      end

      hours
    end

    def remove_breaks(date, periods, breaks)
      return periods if breaks.blank?

      breaks.each do |brk|
        break_start = wall_time(date, brk["start"])
        break_end = wall_time(date, brk["end"])

        index = 0
        while index < periods.length
          period = periods[index]
          index += 1
          next if period.nil?

          period_start = period[:start]
          period_end = period[:end]

          if break_start <= period_start && break_end >= period_start && break_end <= period_end
            period[:start] = break_end
          elsif break_start >= period_start && break_start <= period_end &&
                break_end >= period_start && break_end <= period_end
            period[:end] = break_start
            periods << { start: break_end, end: period_end }
          elsif break_start >= period_start && break_start <= period_end && break_end >= period_end
            period[:end] = break_start
          elsif break_start <= period_start && break_end >= period_end
            period[:start] = break_end
          end
        end
      end

      periods
    end

    def remove_events(periods, events)
      events.each do |event|
        event_start = event.start_datetime
        event_end = event.end_datetime

        index = 0
        while index < periods.length
          period = periods[index]
          index += 1
          next if period.nil?

          period_start = period[:start]
          period_end = period[:end]

          if event_start <= period_start && event_end >= period_start && event_end <= period_end
            period[:start] = event_end
          elsif event_start >= period_start && event_start <= period_end &&
                event_end >= period_start && event_end <= period_end
            period[:end] = event_start
            periods << { start: event_end, end: period_end }
          elsif event_start >= period_start && event_start <= period_end && event_end >= period_end
            period[:end] = event_start
          elsif event_start <= period_start && event_end >= period_end
            period[:start] = event_end
          end
        end
      end

      periods
    end

    def consider_book_advance_timeout(date, hours, provider)
      zone = (@zones ||= {})[provider.id] ||= Time.find_zone!(provider.effective_timezone)
      threshold = now + (@advance_seconds ||= BookingWindows.minutes("book_advance_timeout") * 60)

      hours = hours.reject { |hour| zone.parse("#{date} #{hour}").to_i <= threshold.to_i }
      hours.sort
    end

    def consider_future_booking_limit(date, hours)
      threshold = now + future_booking_limit_days * 86_400
      selected = Time.new(*date.split("-").map(&:to_i))

      threshold.to_i > selected.to_i ? hours : []
    end

    def future_booking_limit_days
      @future_booking_limit_days ||= begin
        limit = Setting.get("future_booking_limit", "90")
        limit.to_s.match?(/\A-?\d+\z/) ? [ limit.to_i, 0 ].max : 90
      end
    end

    def entire_date_blocked?(date)
      return BlockedPeriod.covering_date(date).count > 1 unless @blocked

      blocked_for(date).count > 1
    end

    def exceptions_for(provider_id)
      @exceptions[provider_id] ||= WorkingPlanException.expanded_for(provider_id)
    end

    def events_for(date, provider, exclude_appointment_id)
      return Appointment.covering_date(date, provider.id, exclude_appointment_id).to_a unless @events&.key?(provider.id)

      @events[provider.id].select { |event| covers?(event, date) && event.id != exclude_appointment_id.to_i }
    end

    # for_period(date, date) reduces to the covering condition.
    def blocked_for(date)
      return BlockedPeriod.for_period(date, date).to_a unless @blocked

      @blocked.select { |period| covers?(period, date) }
    end

    def covers?(event, date)
      event.start_datetime.strftime("%Y-%m-%d") <= date && event.end_datetime.strftime("%Y-%m-%d") >= date
    end

    def now
      @now || Time.now
    end

    def weekday(date)
      Date.parse(date).strftime("%A").downcase
    end

    def wall_time(date, hhmm)
      hour, minute = hhmm.split(":").map(&:to_i)
      year, month, day = date.split("-").map(&:to_i)
      Time.new(year, month, day, hour, minute, 0)
    end

    def hhmm(time)
      time.strftime("%H:%M")
    end
  end
end
