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
      "messages_smsgateway_enabled" => "0",
      "messages_smsgateway_default_country_only" => "0",
      "messages_smsgateway_incoming" => "0",
      "messages_smsgateway_url" => "",
      "messages_smsgateway_login" => "",
      "messages_smsgateway_password" => "",
      "messages_smsgateway_signing_key" => "",
      "messages_twilio_enabled" => "0",
      "messages_twilio_default_country_only" => "0",
      "messages_twilio_incoming" => "0",
      "messages_twilio_account_sid" => "",
      "messages_twilio_auth_token" => "",
      "messages_twilio_from" => "",
      "messages_plivo_enabled" => "0",
      "messages_plivo_default_country_only" => "0",
      "messages_plivo_incoming" => "0",
      "messages_plivo_auth_id" => "",
      "messages_plivo_auth_token" => "",
      "messages_plivo_from" => "",
      "messages_textanywhere_enabled" => "0",
      "messages_textanywhere_default_country_only" => "0",
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
          event: "created_or_updated",
          audiences: %w[customer provider admins],
          channels: %w[email],
          short_text: "Your appointment is confirmed",
          long_text: <<~TEXT
            Your appointment has been successfully saved.

            Service: {{Service Name}}
            Provider: {{Provider Name}}
            Date: {{Appointment Date}}
            Time: {{Appointment Time}}
            Repeats: {{Repeats}}

            View or change the appointment: {{Appointment Link}}

            Thank you,
            {{Company Name}}
          TEXT
        },
        {
          title: "Appointment Canceled",
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
        },
        customer_message_notification
      ]
    end

    # Stylists hear about incoming customer messages by email and, when the
    # gateway is activated, SMS.
    def customer_message_notification
      {
        title: "Customer Message Received",
        event: "customer_message",
        audiences: %w[provider],
        channels: %w[email smsgateway],
        short_text: "New message from {{Customer Name}}: {{Customer Message Link}}",
        long_text: <<~TEXT
          {{Customer Name}} has sent you a message.

          Read and reply: {{Customer Message Link}}

          {{Company Name}}
        TEXT
      }
    end

    def create_notifications!
      return unless Notification.none?

      notifications.each { |attrs| Notification.create!(attrs) }
    end

    # Existing installs: the customer message template unless one is set up.
    def create_customer_message_notification!
      return if Notification.exists?(event: "customer_message")

      Notification.create!(customer_message_notification)
    end
  end
end
