# Default settings rows and notification templates for the messages system.
# Used by db/seeds.rb (fresh installs) and the seed_messages_defaults migration
# (existing installs).
module Messaging
  module Defaults
    SETTINGS = {
      # Messages > Settings
      "messages_enabled" => "1",
      "messages_retention_days" => "0",
      "messages_email_subject" => "{{Company Name}} - Appointments",

      # Email provider
      "messages_email_enabled" => "1",
      "messages_email_incoming" => "0",
      "messages_email_mode" => "server", # server | smtp
      "messages_email_smtp_host" => "",
      "messages_email_smtp_port" => "587",
      "messages_email_smtp_username" => "",
      "messages_email_smtp_password" => "",
      "messages_email_smtp_tls" => "1",
      "messages_email_incoming_mode" => "server", # server | imap
      "messages_email_imap_host" => "",
      "messages_email_imap_port" => "993",
      "messages_email_imap_username" => "",
      "messages_email_imap_password" => "",

      # SMS providers
      "messages_twilio_enabled" => "0",
      "messages_twilio_incoming" => "0",
      "messages_twilio_account_sid" => "",
      "messages_twilio_auth_token" => "",
      "messages_twilio_from" => "",
      "messages_plivo_enabled" => "0",
      "messages_plivo_incoming" => "0",
      "messages_plivo_auth_id" => "",
      "messages_plivo_auth_token" => "",
      "messages_plivo_from" => "",
      "messages_textanywhere_enabled" => "0",
      "messages_textanywhere_incoming" => "0",
      "messages_textanywhere_api_key" => "",
      "messages_textanywhere_from" => ""
    }.freeze

    module_function

    # Secret path segment for inbound SMS webhook URLs.
    def inbound_token
      SecureRandom.alphanumeric(32)
    end

    def notifications
      [
        {
          title: "Appointment Created or Updated",
          description: "Confirmation sent whenever an appointment is booked or changed.",
          event: "created_or_updated",
          audiences: %w[customer provider admins],
          channels: %w[email],
          short_text: "Your appointment has been saved",
          long_text: <<~TEXT
            Your appointment has been successfully saved.

            Service: {{Service Name}}
            Provider: {{Provider Name}}
            Date: {{Appointment Date}}
            Time: {{Appointment Time}}

            View or change the appointment: {{Appointment Link}}

            Thank you,
            {{Company Name}}
          TEXT
        },
        {
          title: "Appointment Canceled",
          description: "Sent when an appointment is cancelled or removed.",
          event: "cancelled",
          audiences: %w[customer provider admins],
          channels: %w[email],
          short_text: "Your appointment has been cancelled",
          long_text: <<~TEXT
            The following appointment has been cancelled.

            Service: {{Service Name}}
            Provider: {{Provider Name}}
            Date: {{Appointment Date}}
            Time: {{Appointment Time}}

            Reason: {{Cancellation Reason}}

            {{Company Name}}
          TEXT
        },
        {
          title: "Appointment Reminder in the Morning",
          description: "Reminder text at 8am on the day of the appointment.",
          event: "coming_up",
          lead_mode: "day_at",
          lead_days: 0,
          send_time: "08:00",
          audiences: %w[customer],
          channels: %w[email],
          short_text: "Reminder: your appointment today at {{Appointment Time}}",
          long_text: <<~TEXT
            A reminder that you have an appointment today.

            Service: {{Service Name}}
            Provider: {{Provider Name}}
            Time: {{Appointment Time}}

            See you soon,
            {{Company Name}}
          TEXT
        }
      ]
    end

    def create_notifications!
      return unless Notification.none?

      notifications.each { |attrs| Notification.create!(attrs) }
    end
  end
end
