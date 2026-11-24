# Writes the activity log (ActivityEvent) that the admin Activity page shows.
# Callers pass a kind from KINDS and a summary; the actor comes from
# Current.actor, set per request, and falls back to SYSTEM. Imports wrap their
# work in silenced so bulk loads do not write a line per record.
module Activity
  KINDS = %w[
    appointment_booked appointment_changed appointment_cancelled appointment_deleted
    unavailability_saved unavailability_deleted
    message_sent message_failed message_received
    waitlist_signup reminders_marked
  ].freeze

  # Actor tokens for work that no logged-in user did. The page labels them.
  SYSTEM = "system".freeze
  BOOKING_PAGE = "booking_page".freeze
  API = "api".freeze
  IMPORT = "import".freeze
  ACTOR_TOKENS = [ SYSTEM, BOOKING_PAGE, API, IMPORT ].freeze

  module_function

  # "Edson Mori (Administrator)": the display the page shows for a logged-in user.
  def user_actor(user)
    role = user.role&.name
    role.present? ? "#{user.name} (#{role})" : user.name.to_s
  end

  # Called from Webhooks.trigger for every appointment and unavailability door.
  def appointment_event(action, appointment)
    guard do
      case action
      when Webhooks::APPOINTMENT_SAVE
        kind = appointment.previously_new_record? ? :appointment_booked : :appointment_changed
        record(kind, summary: appointment_summary(appointment), appointment: appointment,
                     details: status_details(appointment))
      when Webhooks::APPOINTMENT_DELETE
        kind = appointment.destroyed? ? :appointment_deleted : :appointment_cancelled
        record(kind, summary: appointment_summary(appointment), appointment: appointment,
                     details: [ status_details(appointment), reason_details(appointment) ].compact.join(". "))
      when Webhooks::UNAVAILABILITY_SAVE
        record(:unavailability_saved, summary: unavailability_summary(appointment), appointment: appointment,
                                      details: appointment.notes.presence)
      when Webhooks::UNAVAILABILITY_DELETE
        record(:unavailability_deleted, summary: unavailability_summary(appointment), appointment: appointment,
                                        details: appointment.notes.presence)
      end
    end
  end

  def appointment_summary(appointment)
    text("activity_appointment_summary", "{{service}} for {{customer}} with {{provider}}, {{when}}",
         service: appointment.service&.name, customer: appointment.customer&.name,
         provider: appointment.provider&.name, when: when_text(appointment))
  end

  def unavailability_summary(appointment)
    "#{appointment.provider&.name}, #{when_text(appointment)}"
  end

  def status_details(appointment)
    text("activity_status_summary", "Status {{status}}", status: appointment.status)
  end

  # cancel! appends the reason to the notes; the last line is the newest.
  def reason_details(appointment)
    reason = appointment.notes.to_s.lines.last.to_s.strip
    reason.present? ? text("activity_reason_summary", "Reason: {{reason}}", reason: reason) : nil
  end

  def when_text(appointment)
    start_at = appointment.start_datetime
    return "" unless start_at

    "#{start_at.strftime('%a %-d %b %Y %H:%M')}-#{appointment.end_datetime&.strftime('%H:%M')}"
  end

  # Incoming: recorded on arrival. Outgoing: recorded once sent or failed.
  def message_event(message)
    guard do
      channel = Messaging.channel(message.channel)&.label || message.channel
      if message.direction == "incoming"
        record(:message_received, message: message, customer: message.customer,
                                  summary: text("activity_received_summary", "From {{address}} by {{channel}}",
                                                address: message.from_address, channel: channel),
                                  details: message.body.to_s.truncate(120).presence)
      else
        kind = message.status == "failed" ? :message_failed : :message_sent
        record(kind, message: message, customer: message.customer, appointment: message.appointment,
                     summary: text("activity_message_summary", "{{notification}} to {{audience}} by {{channel}}, {{address}}",
                                   notification: message.notification&.title || message.subject, audience: message.audience,
                                   channel: channel, address: message.to_address),
                     details: message.error.presence)
      end
    end
  end

  def waitlist_event(entry)
    guard do
      record(:waitlist_signup, summary: text("activity_waitlist_summary", "{{customer}} for {{service}} with {{provider}}",
                                             customer: entry.name, service: entry.service&.name,
                                             provider: entry.provider&.name || "-"),
                               details: entry.email)
    end
  end

  def reminders_marked(count)
    record(:reminders_marked, summary: count.to_s)
  end

  # Admin-facing text in the default locale; {{name}} placeholders are filled in.
  def text(key, default, values)
    values.reduce(I18n.t("ea.#{key}", default: default)) { |out, (name, value)| out.gsub("{{#{name}}}", value.to_s) }
  end

  # The log must never break the action it describes: a builder that fails
  # logs the error and records nothing.
  def guard
    yield
  rescue StandardError => e
    Rails.logger.error("Activity - #{e.class}: #{e.message}")
    nil
  end

  def record(kind, summary:, details: nil, appointment: nil, customer: nil, message: nil, user: nil)
    kind = kind.to_s
    raise ArgumentError, "Unknown activity kind #{kind}" unless KINDS.include?(kind)
    return nil if silenced?

    guard do
      ActivityEvent.create!(
        kind: kind, actor: Current.actor.presence || SYSTEM, summary: summary.to_s, details: details.presence,
        appointment_id: appointment&.id, customer_id: customer&.id || appointment&.id_users_customer,
        message_id: message&.id, user_id: user&.id
      )
    end
  end

  def silenced
    previous = Thread.current[:activity_silenced]
    Thread.current[:activity_silenced] = true
    yield
  ensure
    Thread.current[:activity_silenced] = previous
  end

  def silenced? = Thread.current[:activity_silenced] == true
end
