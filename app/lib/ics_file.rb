# ICS calendar stream for an appointment (EA Ics_file, via the icalendar gem).
# Wall-clock datetimes are interpreted in the provider's timezone with TZID.
module IcsFile
  module_function

  def stream(appointment, service, provider, customer)
    tzid = provider.effective_timezone
    calendar = Icalendar::Calendar.new
    calendar.prodid = "-//OpenAppointments//EN"

    calendar.event do |event|
      event.dtstart = Icalendar::Values::DateTime.new(appointment.start_datetime, "tzid" => tzid)
      event.dtend = Icalendar::Values::DateTime.new(appointment.end_datetime, "tzid" => tzid)
      event.status = "CONFIRMED"
      event.summary = title_for(service, provider)
      event.uid = appointment.id_caldav_calendar.presence || uid_for(appointment.id)
      event.sequence = sequence_for(appointment.updated_at)
      location = location_for(appointment, service)
      event.location = location if location.present?
      event.description = description_for(appointment, provider, customer)

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

  # The appointment's own location, else the service location, else the
  # company address.
  def location_for(appointment, service)
    [ appointment&.location, service&.location, Setting.get("company_address") ].find(&:present?)
  end

  # "{Company}: {Service} with {Stylist}".
  def title_for(service, provider)
    "#{Setting.get('company_name')}: #{service&.name} with #{provider&.name}"
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
      "", I18n.t("ea.customer"), "",
      "#{I18n.t('ea.name')}: #{customer&.full_name}",
      "", I18n.t("ea.notes"), "",
      appointment.notes.to_s
    ]
    lines.join("\n")
  end
end
