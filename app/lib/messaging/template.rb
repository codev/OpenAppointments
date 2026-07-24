# {{Token}} substitution for notification texts. Tokens are matched
# case-insensitively; unknown tokens render empty.
module Messaging
  module Template
    # Shown on the Notifications page guide; keep in sync with context builders.
    TOKENS = [
      "Company Name", "Company Link", "Customer Name", "Customer First Name",
      "Customer Email", "Customer Phone", "Provider Name", "Service Name",
      "Service Duration", "Appointment Date", "Appointment Time",
      "Appointment End Time", "Appointment Status", "Appointment Link",
      "Cancellation Reason", "User Name"
    ].freeze

    module_function

    def render(text, context)
      normalized = context.transform_keys { |key| key.to_s.downcase }
      text.to_s.gsub(/\{\{\s*([^{}]+?)\s*\}\}/) { normalized[Regexp.last_match(1).downcase].to_s }
    end

    def base_context
      {
        "Company Name" => Setting.get("company_name", ""),
        "Company Link" => Setting.get("company_link", "")
      }
    end

    # Tokens for an appointment event, with times shifted into the recipient
    # timezone (appointments store provider-local wall-clock times).
    def appointment_context(appointment:, service:, provider:, customer:, recipient_timezone: nil, reason: nil, link_path: nil)
      start_at, end_at = localized_times(appointment, provider&.timezone, recipient_timezone)
      base_context.merge(
        "Customer Name" => customer&.name.to_s,
        "Customer First Name" => customer&.name.to_s.split(" ").first.to_s,
        "Customer Email" => customer&.email.to_s,
        "Customer Phone" => sms_address(customer).to_s,
        "Provider Name" => provider&.name.to_s,
        "Service Name" => service&.name.to_s,
        "Service Duration" => service&.duration.to_s,
        "Appointment Date" => start_at ? format_date(start_at) : "",
        "Appointment Time" => start_at ? format_time(start_at) : "",
        "Appointment End Time" => end_at ? format_time(end_at) : "",
        "Appointment Status" => appointment&.status.to_s,
        "Appointment Link" => link_path ? "#{base_url}#{link_path}" : "",
        "Cancellation Reason" => reason.to_s
      )
    end

    def sms_address(user)
      return nil unless user

      user.mobile_number.presence || user.phone_number.presence
    end

    def format_date(time)
      format = MailerFormatHelper::DATE_FORMATS[Setting.get("date_format")] ||
               MailerFormatHelper::DATE_FORMATS["DMY"]
      time.strftime(format)
    end

    def format_time(time)
      format = MailerFormatHelper::TIME_FORMATS[Setting.get("time_format")] ||
               MailerFormatHelper::TIME_FORMATS["regular"]
      time.strftime(format).strip
    end

    # EA site_url from the mailer default_url_options.
    def base_url
      options = ActionMailer::Base.default_url_options
      port = options[:port] ? ":#{options[:port]}" : ""
      "#{options[:protocol] || 'http'}://#{options[:host]}#{port}"
    end

    def localized_times(appointment, provider_timezone, recipient_timezone)
      return [ nil, nil ] unless appointment&.start_datetime

      provider_tz = provider_timezone.presence || "UTC"
      recipient_tz = recipient_timezone.presence || provider_tz
      return [ appointment.start_datetime, appointment.end_datetime ] if recipient_tz == provider_tz

      zone = Time.find_zone!(provider_tz)
      target = Time.find_zone!(recipient_tz)
      [ appointment.start_datetime, appointment.end_datetime ].map do |value|
        value && zone.parse(value.strftime("%Y-%m-%d %H:%M:%S")).in_time_zone(target)
      end
    end
  end
end
