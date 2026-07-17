class ApplicationMailer < ActionMailer::Base
  # EA templates are complete self-contained HTML documents, no layout wanted.
  layout nil
  helper :ea
  helper :mailer_format

  # EA embeds assets/img/logo.png as CID in every email.
  before_action { attachments.inline["logo.png"] = Rails.root.join("app/assets/images/logo.png").read }

  private

  # EA from/reply-to fall back to the company settings.
  def company_from
    name = Setting.get("company_name", "OpenAppointments")
    address = Setting.get("company_email", "noreply@example.org")
    email_address_with_name(address, name)
  end

  def company_reply_to
    Setting.get("company_email", "noreply@example.org")
  end

  # EA renders each email in the recipient's language.
  def with_recipient_locale(language_name, &)
    I18n.with_locale(Localization.code_for(language_name.presence || "english"), &)
  end

  # Shift provider-local wall-clock times into the recipient timezone for display.
  def localize_times(appointment, provider_timezone, recipient_timezone)
    provider_tz = provider_timezone.presence || "UTC"
    recipient_tz = recipient_timezone.presence || provider_tz
    return [ appointment.start_datetime, appointment.end_datetime ] if recipient_tz == provider_tz

    zone = Time.find_zone!(provider_tz)
    target = Time.find_zone!(recipient_tz)
    start_at = zone.parse(appointment.start_datetime.strftime("%Y-%m-%d %H:%M:%S")).in_time_zone(target)
    end_at = zone.parse(appointment.end_datetime.strftime("%Y-%m-%d %H:%M:%S")).in_time_zone(target)
    [ start_at, end_at ]
  end
end
