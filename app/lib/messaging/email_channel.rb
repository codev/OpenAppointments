# Email channel. Outgoing goes through the app server mail config ("server"
# mode, Cloudron sendmail addon) or admin-entered SMTP. Incoming is fetched over
# IMAP (or the Cloudron mailbox addon env) into Action Mailbox.
module Messaging
  module EmailChannel
    module_function

    def key = "email"

    def label = "Email"

    def supports_long_text? = true

    def enabled?
      Setting.get("messages_email_enabled", "1") == "1"
    end

    def incoming?
      Setting.get("messages_email_incoming") == "1"
    end

    def address_for(user)
      user&.email.presence
    end

    def deliver(message)
      MessagesMailer.outgoing(message).deliver_now
    end

    # nil when outgoing mode is "server" (use the environment delivery config).
    def smtp_settings
      return nil unless Setting.get("messages_email_mode", "server") == "smtp"

      host = Setting.get("messages_email_smtp_host").presence
      return nil unless host

      username = Setting.get("messages_email_smtp_username").presence
      {
        address: host,
        port: Setting.get("messages_email_smtp_port", "587").to_i,
        user_name: username,
        password: Setting.get("messages_email_smtp_password").presence,
        authentication: username ? :plain : nil,
        enable_starttls_auto: Setting.get("messages_email_smtp_tls", "1") == "1"
      }.compact
    end

    def imap_settings
      if Setting.get("messages_email_incoming_mode", "server") == "server"
        {
          host: ENV["IMAP_HOST"].presence,
          port: ENV.fetch("IMAP_PORT", "993").to_i,
          username: ENV["IMAP_USERNAME"].presence,
          password: ENV["IMAP_PASSWORD"].presence
        }
      else
        {
          host: Setting.get("messages_email_imap_host").presence,
          port: Setting.get("messages_email_imap_port", "993").to_i,
          username: Setting.get("messages_email_imap_username").presence,
          password: Setting.get("messages_email_imap_password").presence
        }
      end
    end
  end
end
