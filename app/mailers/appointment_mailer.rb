# Appointment emails (EA Email_messages::send_appointment_saved/deleted).
class AppointmentMailer < ApplicationMailer
  def saved(appointment:, service:, provider:, customer:, settings:, recipient_email:,
            recipient_language:, recipient_timezone:, manage_mode:, ics:, link_path:, role:)
    with_recipient_locale(recipient_language) do
      @subject =
        if manage_mode
          I18n.t("ea.appointment_details_changed")
        elsif role == :customer
          I18n.t("ea.appointment_booked")
        else
          I18n.t("ea.appointment_added_to_your_plan")
        end
      @message =
        if manage_mode
          ""
        elsif role == :customer
          I18n.t("ea.thank_you_for_appointment")
        else
          I18n.t("ea.appointment_link_description")
        end

      @appointment = appointment
      @service = service
      @provider = provider
      @customer = customer
      @settings = settings
      @timezone = recipient_timezone
      # EA site_url: the app's own base URL, from default_url_options (not company_link).
      options = ActionMailer::Base.default_url_options
      base = "#{options[:protocol] || 'http'}://#{options[:host]}#{options[:port] ? ":#{options[:port]}" : ''}"
      @appointment_link = "#{base}#{link_path}"
      @start_datetime, @end_datetime = localize_times(appointment, provider&.timezone, recipient_timezone)

      attachments["appointment.ics"] = { mime_type: "text/calendar", content: ics }

      mail(to: recipient_email, from: company_from, reply_to: company_reply_to, subject: @subject)
    end
  end

  def deleted(appointment:, service:, provider:, customer:, settings:, recipient_email:,
              recipient_language:, recipient_timezone:, reason: nil)
    with_recipient_locale(recipient_language) do
      @subject = I18n.t("ea.appointment_cancelled_title")
      @appointment = appointment
      @service = service
      @provider = provider
      @customer = customer
      @settings = settings
      @timezone = recipient_timezone
      @reason = reason
      @start_datetime, @end_datetime = localize_times(appointment, provider&.timezone, recipient_timezone)

      mail(to: recipient_email, from: company_from, reply_to: company_reply_to, subject: @subject)
    end
  end
end
