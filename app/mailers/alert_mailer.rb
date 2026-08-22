# Operational alerts to the maintainer, sent through the platform mailer like
# crash reports. Plain text, no company branding.
class AlertMailer < ActionMailer::Base
  default from: %("OpenAppointments Administrator" <#{ENV.fetch('CLOUDRON_MAIL_FROM', 'info@codev.uk')}>)

  # A message could not be delivered by its provider; details are in the Messages log.
  def message_failed(message)
    zone = Time.find_zone(Setting.get("default_timezone", "UTC")) || Time.zone
    @failed_at = (message.updated_at || Time.current).in_time_zone(zone).strftime("%Y-%m-%d %H:%M %Z")
    @provider = message.channel

    mail(to: self.class.failure_recipients, subject: "[OpenAppointments] Message delivery failed: #{@provider}")
  end

  # The configured list, else every admin.
  def self.failure_recipients
    configured = Setting.get("messages_failure_alert_emails").to_s.split(/[\s,;]+/).reject(&:blank?)
    configured.presence || User.admins.pluck(:email).compact_blank
  end
end
