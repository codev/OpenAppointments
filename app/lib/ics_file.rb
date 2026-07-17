# ICS calendar stream for an appointment (EA Ics_file, via the icalendar gem).
# Wall-clock datetimes are interpreted in the provider's timezone with TZID.
module IcsFile
  module_function

  def stream(appointment, service, provider, customer)
    tzid = provider.timezone.presence || "UTC"
    calendar = Icalendar::Calendar.new
    calendar.prodid = "-//OpenAppointments//EN"

    calendar.event do |event|
      event.dtstart = Icalendar::Values::DateTime.new(appointment.start_datetime, "tzid" => tzid)
      event.dtend = Icalendar::Values::DateTime.new(appointment.end_datetime, "tzid" => tzid)
      event.status = "CONFIRMED"
      event.summary = service&.name.to_s
      event.uid = appointment.id_caldav_calendar.presence || uid_for(appointment.id)
      event.sequence = sequence_for(appointment.updated_at)
      event.location = service.location if service&.location.present?
      event.description = description_for(appointment, provider, customer)

      if customer&.email.present?
        event.append_attendee(
          Icalendar::Values::CalAddress.new("mailto:#{customer.email}",
                                            "CN" => customer.full_name, "CUTYPE" => "INDIVIDUAL",
                                            "ROLE" => "REQ-PARTICIPANT", "PARTSTAT" => "NEEDS-ACTION",
                                            "RSVP" => "TRUE")
        )
      end
      if provider&.email.present?
        event.append_attendee(Icalendar::Values::CalAddress.new("mailto:#{provider.email}",
                                                                "CN" => provider.full_name))
      end

      [ 15, 60 ].each do |minutes_before|
        event.alarm do |alarm|
          alarm.action = "DISPLAY"
          alarm.summary = "Alarm notification"
          alarm.description = "This is an event reminder"
          alarm.trigger = "-PT#{minutes_before}M"
        end
      end
    end

    calendar.to_ical
  end

  def uid_for(appointment_id)
    Digest::MD5.hexdigest("openappointments-appointment-#{appointment_id}")
  end

  def sequence_for(updated_at)
    updated_at ? updated_at.to_i % 2_147_483_647 : 0
  end

  def description_for(appointment, provider, customer)
    lines = []
    if appointment.meeting_link.present?
      lines += [ "", "#{I18n.t('ea.meeting_link')}: #{appointment.meeting_link}", "" ]
    end
    lines += [
      "", I18n.t("ea.provider"), "",
      "#{I18n.t('ea.name')}: #{provider&.full_name}",
      "#{I18n.t('ea.email')}: #{provider&.email}",
      "#{I18n.t('ea.phone_number')}: #{provider&.phone_number}",
      "", I18n.t("ea.customer"), "",
      "#{I18n.t('ea.name')}: #{customer&.full_name}",
      "#{I18n.t('ea.email')}: #{customer&.email}",
      "#{I18n.t('ea.phone_number')}: #{customer&.phone_number.presence || '-'}",
      "", I18n.t("ea.notes"), "",
      appointment.notes.to_s
    ]
    lines.join("\n")
  end
end
