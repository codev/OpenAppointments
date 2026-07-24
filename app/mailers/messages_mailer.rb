# Sends outgoing Message records on the email channel. Body text comes from the
# rendered notification template (or a manual send); appointment confirmations
# keep the ICS attachment.
class MessagesMailer < ApplicationMailer
  ICS_EVENTS = %w[created created_or_updated updated].freeze

  def outgoing(message)
    @message = message
    @company_color = Setting.get("company_color").presence || "#429A82"

    appointment = message.appointment
    if appointment && ICS_EVENTS.include?(message.notification&.event)
      ics = IcsFile.stream(appointment, appointment.service, appointment.provider, appointment.customer)
      attachments["appointment.ics"] = { mime_type: "text/calendar", content: ics }
    end

    built = mail(to: message.to_address, from: company_from, reply_to: company_reply_to,
                 subject: message.subject)
    if (smtp = Messaging::EmailChannel.smtp_settings)
      built.delivery_method(:smtp, smtp)
    end
    built
  end
end
