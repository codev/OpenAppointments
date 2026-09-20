# One way calendar feed for a provider: their appointments and unavailabilities
# in the sync window as an ICS calendar that calendar apps subscribe to by URL.
# Events carry the service and customer name and a link to the record here,
# never the customer's contact details.
module CalendarFeed
  module_function

  def ics(provider, now: Time.now)
    settings = provider.settings
    from = now - (settings&.sync_past_days || 30).to_i.days
    to = now + (settings&.sync_future_days || 90).to_i.days
    tzid = provider.effective_timezone

    calendar = Icalendar::Calendar.new
    calendar.prodid = "-//OpenAppointments//EN"
    calendar.append_custom_property("X-WR-CALNAME", "#{Setting.get('company_name')} - #{provider.name}")
    calendar.append_custom_property("X-WR-TIMEZONE", tzid)
    calendar.append_custom_property("X-PUBLISHED-TTL", "PT1H")

    records = provider.provider_appointments.where(start_datetime: from..to)
                      .includes(:service, :customer, :appointment_status).order(:start_datetime)
    records.reject(&:frees_slot?).each { |record| calendar.add_event(event_for(record, tzid)) }
    calendar.to_ical
  end

  def event_for(record, tzid)
    event = Icalendar::Event.new
    event.uid = IcsFile.uid_for(record.id)
    event.dtstart = Icalendar::Values::DateTime.new(record.start_datetime, "tzid" => tzid)
    event.dtend = Icalendar::Values::DateTime.new(record.end_datetime, "tzid" => tzid)
    event.sequence = IcsFile.sequence_for(record.updated_at)
    if record.is_unavailability
      event.summary = record.notes.presence || I18n.t("ea.unavailable")
    else
      event.summary = [ record.service&.name, record.customer&.full_name ].compact_blank.join(" - ")
      event.description = "#{SyncUrls.base_url}/calendar/reschedule/#{record.booking_hash}"
      event.status = "CONFIRMED"
    end
    event
  end
end
