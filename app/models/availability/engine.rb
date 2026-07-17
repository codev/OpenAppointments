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
      exceptions = WorkingPlanException.expanded_for(provider.id)

      events = Appointment.covering_date(date, provider.id, exclude_appointment_id).to_a +
               BlockedPeriod.for_period(date, date).to_a

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
      unavailabilities = Appointment.unavailabilities.covering_date(date, provider.id, exclude_appointment_id).to_a
      blocked = BlockedPeriod.for_period(date, date).to_a

      exceptions = WorkingPlanException.expanded_for(provider.id)
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
      zone = Time.find_zone!(provider.timezone.presence || "UTC")
      timeout = Setting.get("book_advance_timeout", "0")
      timeout = timeout.to_s.match?(/\A-?\d+\z/) ? [ timeout.to_i, 0 ].max : 0

      threshold = now + timeout * 60

      hours = hours.reject { |hour| zone.parse("#{date} #{hour}").to_i <= threshold.to_i }
      hours.sort
    end

    def consider_future_booking_limit(date, hours)
      limit = Setting.get("future_booking_limit", "90")
      limit = limit.to_s.match?(/\A-?\d+\z/) ? [ limit.to_i, 0 ].max : 90

      threshold = now + limit * 86_400
      selected = Time.new(*date.split("-").map(&:to_i))

      threshold.to_i > selected.to_i ? hours : []
    end

    def entire_date_blocked?(date)
      BlockedPeriod.covering_date(date).count > 1
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
